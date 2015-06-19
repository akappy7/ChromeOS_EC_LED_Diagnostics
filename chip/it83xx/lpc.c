/* Copyright (c) 2014 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/* LPC module for Chrome EC */

#include "acpi.h"
#include "clock.h"
#include "common.h"
#include "console.h"
#include "gpio.h"
#include "hooks.h"
#include "host_command.h"
#include "keyboard_protocol.h"
#include "lpc.h"
#include "port80.h"
#include "pwm.h"
#include "registers.h"
#include "system.h"
#include "task.h"
#include "timer.h"
#include "uart.h"
#include "util.h"
#include "irq_chip.h"

/* Console output macros */
#define CPUTS(outstr) cputs(CC_LPC, outstr)
#define CPRINTS(format, args...) cprints(CC_LPC, format, ## args)

/* LPC PM channels */
enum lpc_pm_ch {
	LPC_PM1 = 0,
	LPC_PM2,
	LPC_PM3,
	LPC_PM4,
	LPC_PM5,
};

enum pm_ctrl_mask {
	/* Input Buffer Full Interrupt Enable. */
	PM_CTRL_IBFIE = 0x01,
	/* Output Buffer Empty Interrupt Enable. */
	PM_CTRL_OBEIE = 0x02,
};

#define LPC_ACPI_CMD      LPC_PM1   /* ACPI commands 62h/66h port */
#define LPC_HOST_CMD      LPC_PM2   /* Host commands 200h/204h port */
#define LPC_HOST_PORT_80H LPC_PM3   /* Host 80h port */

static uint8_t acpi_ec_memmap[EC_MEMMAP_SIZE]
			__attribute__((section(".h2ram.pool.acpiec")));
static uint8_t host_cmd_memmap[256]
			__attribute__((section(".h2ram.pool.hostcmd")));

static uint32_t host_events;     /* Currently pending SCI/SMI events */
static uint32_t event_mask[3];   /* Event masks for each type */
static struct host_packet lpc_packet;
static struct host_cmd_handler_args host_cmd_args;
static uint8_t host_cmd_flags;   /* Flags from host command */

/* Params must be 32-bit aligned */
static uint8_t params_copy[EC_LPC_HOST_PACKET_SIZE] __aligned(4);
static int init_done;

static uint8_t * const cmd_params = (uint8_t *)host_cmd_memmap +
	EC_LPC_ADDR_HOST_PARAM - EC_LPC_ADDR_HOST_ARGS;
static struct ec_lpc_host_args * const lpc_host_args =
	(struct ec_lpc_host_args *)host_cmd_memmap;

static void pm_set_ctrl(enum lpc_pm_ch ch, enum pm_ctrl_mask ctrl, int set)
{
	if (set)
		IT83XX_PMC_PMCTL(ch) |= ctrl;
	else
		IT83XX_PMC_PMCTL(ch) &= ~ctrl;
}

static void pm_set_status(enum lpc_pm_ch ch, uint8_t status, int set)
{
	if (set)
		IT83XX_PMC_PMSTS(ch) |= status;
	else
		IT83XX_PMC_PMSTS(ch) &= ~status;
}

static uint8_t pm_get_status(enum lpc_pm_ch ch)
{
	return IT83XX_PMC_PMSTS(ch);
}

static uint8_t pm_get_data_in(enum lpc_pm_ch ch)
{
	return IT83XX_PMC_PMDI(ch);
}

static void pm_put_data_out(enum lpc_pm_ch ch, uint8_t out)
{
	IT83XX_PMC_PMDO(ch) = out;
}

/**
 * Generate SMI pulse to the host chipset via GPIO.
 *
 * If the x86 is in S0, SMI# is sampled at 33MHz, so minimum pulse length is
 * 60ns.  If the x86 is in S3, SMI# is sampled at 32.768KHz, so we need pulse
 * length >61us.  Both are short enough and events are infrequent, so just
 * delay for 65us.
 */
static void lpc_generate_smi(void)
{
	gpio_set_level(GPIO_PCH_SMI_L, 0);
	udelay(65);
	gpio_set_level(GPIO_PCH_SMI_L, 1);
}

static void lpc_generate_sci(void)
{
	gpio_set_level(GPIO_PCH_SCI_L, 0);
	udelay(65);
	gpio_set_level(GPIO_PCH_SCI_L, 1);
}

/**
 * Update the level-sensitive wake signal to the AP.
 *
 * @param wake_events	Currently asserted wake events
 */
static void lpc_update_wake(uint32_t wake_events)
{
	/*
	 * Mask off power button event, since the AP gets that through a
	 * separate dedicated GPIO.
	 */
	wake_events &= ~EC_HOST_EVENT_MASK(EC_HOST_EVENT_POWER_BUTTON);

	/* Signal is asserted low when wake events is non-zero */
	gpio_set_level(GPIO_PCH_WAKE_L, !wake_events);
}

static void lpc_send_response(struct host_cmd_handler_args *args)
{
	uint8_t *out;
	int size = args->response_size;
	int csum;
	int i;

	/* Ignore in-progress on LPC since interface is synchronous anyway */
	if (args->result == EC_RES_IN_PROGRESS)
		return;

	/* Handle negative size */
	if (size < 0) {
		args->result = EC_RES_INVALID_RESPONSE;
		size = 0;
	}

	/* New-style response */
	lpc_host_args->flags =
		(host_cmd_flags & ~EC_HOST_ARGS_FLAG_FROM_HOST) |
		EC_HOST_ARGS_FLAG_TO_HOST;

	lpc_host_args->data_size = size;

	csum = args->command + lpc_host_args->flags +
		lpc_host_args->command_version +
		lpc_host_args->data_size;

	for (i = 0, out = (uint8_t *)args->response; i < size; i++, out++)
		csum += *out;

	lpc_host_args->checksum = (uint8_t)csum;

	/* Fail if response doesn't fit in the param buffer */
	if (size > EC_PROTO2_MAX_PARAM_SIZE)
		args->result = EC_RES_INVALID_RESPONSE;

	/* Write result to the data byte.  This sets the OBF status bit. */
	pm_put_data_out(LPC_HOST_CMD, args->result);

	/* Clear the busy bit, so the host knows the EC is done. */
	pm_set_status(LPC_HOST_CMD, EC_LPC_STATUS_PROCESSING, 0);
}

static void update_host_event_status(void)
{
	int need_sci = 0;
	int need_smi = 0;

	if (!init_done)
		return;

	/* Disable PMC1 interrupt while updating status register */
	task_disable_irq(IT83XX_IRQ_PMC_IN);

	if (host_events & event_mask[LPC_HOST_EVENT_SMI]) {
		/* Only generate SMI for first event */
		if (!(pm_get_status(LPC_ACPI_CMD) & EC_LPC_STATUS_SMI_PENDING))
			need_smi = 1;
		pm_set_status(LPC_ACPI_CMD, EC_LPC_STATUS_SMI_PENDING, 1);
	} else {
		pm_set_status(LPC_ACPI_CMD, EC_LPC_STATUS_SMI_PENDING, 0);
	}

	if (host_events & event_mask[LPC_HOST_EVENT_SCI]) {
		/* Generate SCI for every event */
		need_sci = 1;
		pm_set_status(LPC_ACPI_CMD, EC_LPC_STATUS_SCI_PENDING, 1);
	} else {
		pm_set_status(LPC_ACPI_CMD, EC_LPC_STATUS_SCI_PENDING, 0);
	}

	/* Copy host events to mapped memory */
	*(uint32_t *)host_get_memmap(EC_MEMMAP_HOST_EVENTS) = host_events;

	task_enable_irq(IT83XX_IRQ_PMC_IN);

	/* Process the wake events. */
	lpc_update_wake(host_events & event_mask[LPC_HOST_EVENT_WAKE]);

	/* Send pulse on SMI signal if needed */
	if (need_smi)
		lpc_generate_smi();

	/* ACPI 5.0-12.6.1: Generate SCI for SCI_EVT=1. */
	if (need_sci)
		lpc_generate_sci();
}

static void lpc_send_response_packet(struct host_packet *pkt)
{
	/* Ignore in-progress on LPC since interface is synchronous anyway */
	if (pkt->driver_result == EC_RES_IN_PROGRESS)
		return;

	/* Write result to the data byte. */
	pm_put_data_out(LPC_HOST_CMD, pkt->driver_result);

	/* Clear the busy bit, so the host knows the EC is done. */
	pm_set_status(LPC_HOST_CMD, EC_LPC_STATUS_PROCESSING, 0);
}

uint8_t *lpc_get_memmap_range(void)
{
	return (uint8_t *)acpi_ec_memmap;
}

int lpc_keyboard_has_char(void)
{
	/* OBE or OBF */
	return IT83XX_KBC_KBHISR & 0x01;
}

int lpc_keyboard_input_pending(void)
{
	/* IBE or IBF */
	return IT83XX_KBC_KBHISR & 0x02;
}

void lpc_keyboard_put_char(uint8_t chr, int send_irq)
{
	/* Clear programming data bit 7-4 */
	IT83XX_KBC_KBHISR &= 0x0F;

	/* keyboard */
	IT83XX_KBC_KBHISR |= 0x10;

	/*
	 * bit0 = 0, The IRQ1 is controlled by the IRQ1B bit in KBIRQR.
	 * bit1 = 0, The IRQ12 is controlled by the IRQ12B bit in KBIRQR.
	 */
	IT83XX_KBC_KBHICR &= 0xFC;

	/*
	 * Enable the interrupt to keyboard driver in the host processor
	 * via SERIRQ when the output buffer is full.
	 */
	if (send_irq)
		IT83XX_KBC_KBHICR |= 0x01;

	udelay(16);

	/* The data output to the KBC Data Output Register. */
	IT83XX_KBC_KBHIKDOR = chr;
}

void lpc_keyboard_clear_buffer(void)
{
	/* --- (not implemented yet) --- */
}

void lpc_keyboard_resume_irq(void)
{
	if (lpc_keyboard_has_char()) {
		/* The IRQ1 is controlled by the IRQ1B bit in KBIRQR. */
		IT83XX_KBC_KBHICR &= ~0x01;

		/*
		 * When the OBFKIE bit in KBC Host Interface Control Register
		 * (KBHICR) is 0, the bit directly controls the IRQ1 signal.
		 */
		IT83XX_KBC_KBIRQR |= 0x01;

		task_clear_pending_irq(IT83XX_IRQ_KBC_OUT);

		task_enable_irq(IT83XX_IRQ_KBC_OUT);
	}
}

void lpc_set_host_event_state(uint32_t mask)
{
	if (mask != host_events) {
		host_events = mask;
		update_host_event_status();
	}
}

int lpc_query_host_event_state(void)
{
	const uint32_t any_mask = event_mask[0] | event_mask[1] | event_mask[2];
	int evt_index = 0;
	int i;

	for (i = 0; i < 32; i++) {
		const uint32_t e = (1 << i);

		if (host_events & e) {
			host_clear_events(e);

			/*
			 * If host hasn't unmasked this event, drop it.  We do
			 * this at query time rather than event generation time
			 * so that the host has a chance to unmask events
			 * before they're dropped by a query.
			 */
			if (!(e & any_mask))
				continue;

			evt_index = i + 1;	/* Events are 1-based */
			break;
		}
	}

	return evt_index;
}

void lpc_set_host_event_mask(enum lpc_host_event_type type, uint32_t mask)
{
	event_mask[type] = mask;
	update_host_event_status();
}

uint32_t lpc_get_host_event_mask(enum lpc_host_event_type type)
{
	return event_mask[type];
}

void lpc_set_acpi_status_mask(uint8_t mask)
{
	pm_set_status(LPC_ACPI_CMD, mask, 1);
}

void lpc_clear_acpi_status_mask(uint8_t mask)
{
	pm_set_status(LPC_ACPI_CMD, mask, 0);
}

int lpc_get_pltrst_asserted(void)
{
	return !gpio_get_level(GPIO_PCH_PLTRST_L);
}

/* KBC and PMC control modules */
void lpc_kbc_ibf_interrupt(void)
{
	if (lpc_keyboard_input_pending()) {
		keyboard_host_write(IT83XX_KBC_KBHIDIR,
			(IT83XX_KBC_KBHISR & 0x08) ? 1 : 0);
	}

	task_clear_pending_irq(IT83XX_IRQ_KBC_IN);
}

void lpc_kbc_obe_interrupt(void)
{
	task_disable_irq(IT83XX_IRQ_KBC_OUT);

	task_clear_pending_irq(IT83XX_IRQ_KBC_OUT);

	if (!(IT83XX_KBC_KBHICR & 0x01)) {
		IT83XX_KBC_KBIRQR &= ~0x01;

		IT83XX_KBC_KBHICR |= 0x01;
	}
}

void pm1_ibf_interrupt(void)
{
	int is_cmd;
	uint8_t value, result;

	if (pm_get_status(LPC_ACPI_CMD) & EC_LPC_STATUS_FROM_HOST) {
		/* Set the busy bit */
		pm_set_status(LPC_ACPI_CMD, EC_LPC_STATUS_PROCESSING, 1);

		/* data from command port or data port */
		is_cmd = pm_get_status(LPC_ACPI_CMD) & EC_LPC_STATUS_LAST_CMD;

		/* Get command or data */
		value = pm_get_data_in(LPC_ACPI_CMD);

		/* Handle whatever this was. */
		if (acpi_ap_to_ec(is_cmd, value, &result))
			pm_put_data_out(LPC_ACPI_CMD, result);

		/* Clear the busy bit */
		pm_set_status(LPC_ACPI_CMD, EC_LPC_STATUS_PROCESSING, 0);

		/*
		 * ACPI 5.0-12.6.1: Generate SCI for Input Buffer Empty
		 * Output Buffer Full condition on the kernel channel.
		 */
		lpc_generate_sci();
	}

	task_clear_pending_irq(IT83XX_IRQ_PMC_IN);
}

void pm2_ibf_interrupt(void)
{
	uint8_t value __attribute__((unused)) = 0;
	uint8_t status;

	status = pm_get_status(LPC_HOST_CMD);
	/* IBE */
	if (!(status & EC_LPC_STATUS_FROM_HOST)) {
		task_clear_pending_irq(IT83XX_IRQ_PMC2_IN);
		return;
	}

	/* IBF and data port */
	if (!(status & EC_LPC_STATUS_LAST_CMD)) {
		/* R/C IBF*/
		value = pm_get_data_in(LPC_HOST_CMD);
		task_clear_pending_irq(IT83XX_IRQ_PMC2_IN);
		return;
	}

	/* Set the busy bit */
	pm_set_status(LPC_HOST_CMD, EC_LPC_STATUS_PROCESSING, 1);

	/*
	 * Read the command byte.  This clears the FRMH bit in
	 * the status byte.
	 */
	host_cmd_args.command = pm_get_data_in(LPC_HOST_CMD);

	host_cmd_args.result = EC_RES_SUCCESS;
	if (host_cmd_args.command != EC_COMMAND_PROTOCOL_3)
		host_cmd_args.send_response = lpc_send_response;
	host_cmd_flags = lpc_host_args->flags;

	/* We only support new style command (v3) now */
	if (host_cmd_args.command == EC_COMMAND_PROTOCOL_3) {
		lpc_packet.send_response = lpc_send_response_packet;

		lpc_packet.request = (const void *)host_cmd_memmap;
		lpc_packet.request_temp = params_copy;
		lpc_packet.request_max = sizeof(params_copy);
		/* Don't know the request size so pass in the entire buffer */
		lpc_packet.request_size = EC_LPC_HOST_PACKET_SIZE;

		lpc_packet.response = (void *)host_cmd_memmap;
		lpc_packet.response_max = EC_LPC_HOST_PACKET_SIZE;
		lpc_packet.response_size = 0;

		lpc_packet.driver_result = EC_RES_SUCCESS;
		host_packet_receive(&lpc_packet);

		task_clear_pending_irq(IT83XX_IRQ_PMC2_IN);
		return;
	} else {
		/* Old style command, now unsupported */
		host_cmd_args.result = EC_RES_INVALID_COMMAND;
	}

	/* Hand off to host command handler */
	host_command_received(&host_cmd_args);

	task_clear_pending_irq(IT83XX_IRQ_PMC2_IN);
}

void pm3_ibf_interrupt(void)
{
	if (pm_get_status(LPC_HOST_PORT_80H) & EC_LPC_STATUS_FROM_HOST)
		port_80_write(pm_get_data_in(LPC_HOST_PORT_80H));

	task_clear_pending_irq(IT83XX_IRQ_PMC3_IN);
}

void pm4_ibf_interrupt(void)
{
	task_clear_pending_irq(IT83XX_IRQ_PMC4_IN);
}

void pm5_ibf_interrupt(void)
{
	task_clear_pending_irq(IT83XX_IRQ_PMC5_IN);
}

static void lpc_init(void)
{
	/*
	 * DLM 52k~56k size select enable.
	 * For mapping LPC I/O cycle 800h ~ 9FFh to DLM 8D800 ~ 8D9FF.
	 */
	IT83XX_GCTRL_MCCR2 |= 0x10;

	IT83XX_GPIO_GCR = 0x06;

	/* The register pair to access PNPCFG is 002Eh and 002Fh */
	IT83XX_GCTRL_BADRSEL = 0x00;

	/* Disable KBC IRQ */
	IT83XX_KBC_KBIRQR = 0x00;

	/*
	 * bit2, Output Buffer Empty CPU Interrupt Enable.
	 * bit3, Input Buffer Full CPU Interrupt Enable.
	 */
	IT83XX_KBC_KBHICR |= 0x0C;

	/* PM1 Input Buffer Full Interrupt Enable for 62h/66 port */
	pm_set_ctrl(LPC_ACPI_CMD, PM_CTRL_IBFIE, 1);

	/* PM2 Input Buffer Full Interrupt Enable for 200h/204 port */
	pm_set_ctrl(LPC_HOST_CMD, PM_CTRL_IBFIE, 1);

	memset(lpc_get_memmap_range(), 0, EC_MEMMAP_SIZE);
	memset(lpc_host_args, 0, sizeof(*lpc_host_args));

	/* Host LPC I/O cycle mapping to RAM */
	/*
	 * bit[4], H2RAM through LPC IO cycle.
	 * bit[1], H2RAM window 1 enabled.
	 * bit[0], H2RAM window 0 enabled.
	 */
	IT83XX_SMFI_HRAMWC |= 0x13;

	/*
	 * bit[7:6]
	 * Host RAM Window[x] Read Protect Enable
	 * 00b: Disabled
	 * 01b: Lower half of RAM window protected
	 * 10b: Upper half of RAM window protected
	 * 11b: All protected
	 *
	 * bit[5:4]
	 * Host RAM Window[x] Write Protect Enable
	 * 00b: Disabled
	 * 01b: Lower half of RAM window protected
	 * 10b: Upper half of RAM window protected
	 * 11b: All protected
	 *
	 * bit[2:0]
	 * Host RAM Window 1 Size (HRAMW1S)
	 * 0h: 16 bytes
	 * 1h: 32 bytes
	 * 2h: 64 bytes
	 * 3h: 128 bytes
	 * 4h: 256 bytes
	 * 5h: 512 bytes
	 * 6h: 1024 bytes
	 * 7h: 2048 bytes
	 */

	/* H2RAM Win 0 Base Address 800h allow r/w for host_cmd_memmap */
	IT83XX_SMFI_HRAMW0BA = 0x80;
	IT83XX_SMFI_HRAMW0AAS = 0x04;

	/* H2RAM Win 1 Base Address 900h allow r for acpi_ec_memmap */
	IT83XX_SMFI_HRAMW1BA = 0x90;
	IT83XX_SMFI_HRAMW1AAS = 0x34;

	/* We support LPC args and version 3 protocol */
	*(lpc_get_memmap_range() + EC_MEMMAP_HOST_CMD_FLAGS) =
		EC_HOST_CMD_FLAG_LPC_ARGS_SUPPORTED |
		EC_HOST_CMD_FLAG_VERSION_3;

	/*
	 * bit[5], Dedicated interrupt
	 * INT3: PMC1 Output Buffer Empty Int
	 * INT25: PMC1 Input Buffer Full Int
	 * INT26: PMC2 Output Buffer Empty Int
	 * INT27: PMC2 Input Buffer Full Int
	 */
	IT83XX_PMC_MBXCTRL |= 0x20;

	/* PM3 Input Buffer Full Interrupt Enable for 80h port */
	pm_set_ctrl(LPC_HOST_PORT_80H, PM_CTRL_IBFIE, 1);

	gpio_enable_interrupt(GPIO_PCH_PLTRST_L);

	task_clear_pending_irq(IT83XX_IRQ_KBC_OUT);
	task_disable_irq(IT83XX_IRQ_KBC_OUT);

	task_clear_pending_irq(IT83XX_IRQ_KBC_IN);
	task_enable_irq(IT83XX_IRQ_KBC_IN);

	task_clear_pending_irq(IT83XX_IRQ_PMC_IN);
	task_enable_irq(IT83XX_IRQ_PMC_IN);

	task_clear_pending_irq(IT83XX_IRQ_PMC2_IN);
	task_enable_irq(IT83XX_IRQ_PMC2_IN);

	task_clear_pending_irq(IT83XX_IRQ_PMC3_IN);
	task_enable_irq(IT83XX_IRQ_PMC3_IN);

	/* Sufficiently initialized */
	init_done = 1;

	/* Update host events now that we can copy them to memmap */
	update_host_event_status();
}
/*
 * Set prio to higher than default; this way LPC memory mapped data is ready
 * before other inits try to initialize their memmap data.
 */
DECLARE_HOOK(HOOK_INIT, lpc_init, HOOK_PRIO_INIT_LPC);

void lpcrst_interrupt(enum gpio_signal signal)
{
	if (lpc_get_pltrst_asserted())
		/* Store port 80 reset event */
		port_80_write(PORT_80_EVENT_RESET);

	CPRINTS("LPC RESET# %sasserted",
		lpc_get_pltrst_asserted() ? "" : "de");
}

/* Enable LPC ACPI-EC interrupts */
void lpc_enable_acpi_interrupts(void)
{
	task_enable_irq(IT83XX_IRQ_PMC_IN);
}

/* Disable LPC ACPI-EC interrupts */
void lpc_disable_acpi_interrupts(void)
{
	task_disable_irq(IT83XX_IRQ_PMC_IN);
}

static void lpc_resume(void)
{
	/* Mask all host events until the host unmasks them itself.  */
	lpc_set_host_event_mask(LPC_HOST_EVENT_SMI, 0);
	lpc_set_host_event_mask(LPC_HOST_EVENT_SCI, 0);
	lpc_set_host_event_mask(LPC_HOST_EVENT_WAKE, 0);

	/* Store port 80 event so we know where resume happened */
	port_80_write(PORT_80_EVENT_RESUME);
}
DECLARE_HOOK(HOOK_CHIPSET_RESUME, lpc_resume, HOOK_PRIO_DEFAULT);

/* Get protocol information */
static int lpc_get_protocol_info(struct host_cmd_handler_args *args)
{
	struct ec_response_get_protocol_info *r = args->response;

	memset(r, 0, sizeof(*r));
	r->protocol_versions = (1 << 3);
	r->max_request_packet_size = EC_LPC_HOST_PACKET_SIZE;
	r->max_response_packet_size = EC_LPC_HOST_PACKET_SIZE;
	r->flags = 0;

	args->response_size = sizeof(*r);

	return EC_SUCCESS;
}
DECLARE_HOST_COMMAND(EC_CMD_GET_PROTOCOL_INFO,
		lpc_get_protocol_info,
		EC_VER_MASK(0));

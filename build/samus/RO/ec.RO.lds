/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Copyright (c) 2014 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/*
 * config.h - Top-level configuration Chrome EC
 *
 * All configuration settings (CONFIG_*) are defined in this file or in a
 * sub-configuration file (config_chip.h, board.h, etc.) included by this file.
 *
 * Note that this file is included by assembly (.S) files.  Any C-isms such as
 * struct definitions or enums in a sub-configuration file MUST be guarded with
 * #ifndef __ASSEMBLER__ to prevent those C-isms from being evaluated by the
 * assembler.
 */
/*
 * All config options are listed alphabetically and described here.
 *
 * If you add a new config option somewhere in the code, you must add a
 * default value here and describe what it does.
 *
 * To get a list current list, run this command:
 *    git grep " CONFIG_" | grep -o "CONFIG_[A-Za-z0-9_]\+" | sort | uniq
 *
 * Some options are #defined here to enable them by default.  Chips or boards
 * may override this by #undef'ing them in config_chip.h or board.h,
 * respectively.
 *
 * TODO(crosbug.com/p/23758): Describe all of these.  Also describe the
 * HAS_TASK_* macro and how/when it should be used vs. a config define.  And
 * BOARD_*, CHIP_*, and CHIP_FAMILY_*.
 */
/* Enable accelerometer interrupts. */
/* Add support for sensor FIFO:
 * define the size of the global fifo, must be a power of 2. */
/* The amount of free entries that trigger an interrupt to the AP. */
/*
 * Sensors in this mask are in forced mode: they needed to be polled
 * at their data rate frequency.
 */
/* Specify type of accelerometers attached. */
/*
 * Use the old standard reference frame for accelerometers. The old
 * reference frame is:
 * Z-axis: perpendicular to keyboard, pointing up, such that if the device
 *  is sitting flat on a table, the accel reads +G.
 * X-axis: in the plane of the keyboard, pointing from the front lip to the
 *  hinge, such that if the device is oriented with the front lip touching
 *  the table and the hinge directly above, the accel reads +G.
 * Y-axis: in the plane of the keyboard, pointing to the right, such that
 *  if the device is on it's left side, the accel reads +G.
 *
 * Also, in the old reference frame, the lid accel matches the base accel
 * readings when lid is closed.
 */
/*
 * Define the event to raise when BMI160 interrupt.
 * Must be within TASK_EVENT_MOTION_INTERRUPT_MASK.
 */
/* Specify type of Gyrometers attached. */
/* Compile chip support for analog-to-digital convertor */
/*
 * ADC sample time selection. The value is chip-dependent.
 * TODO: Replace this with CONFIG_ADC_PROFILE entries.
 */
/* Include the ADC analog watchdog feature in the ADC code */
/*
 * Chip-dependent ADC configuration - select one.
 * SINGLE - Sample all inputs once when requested.
 * FAST_CONTINUOUS - Sample all inputs continuously using DMA, with minimal
 *                   sample time.
 */
/*
 * Some ALS modules may be connected to the EC. We need the command, and
 * specific drivers for each module.
 */
/* Define the exact model ID present on the board: SI1141 = 41, SI1142 = 42, */
/* Check if the device revision is supported */
/*
 * Define the event to raise when BMI160 interrupt.
 * Must be within TASK_EVENT_MOTION_INTERRUPT_MASK.
 */
/* Define which ALS sensor is used for dimming the lightbar when dark */
/* Support AP hang detection host command and state machine */
/* Support AP Warm reset Interrupt. */
/* Allow proprietary communication protocols' extensions. */
/*
 * Support controlling the display backlight based on the state of the lid
 * switch.  The EC will disable the backlight when the lid is closed.
 */
/*
 * If defined, EC will enable the backlight signal only if this GPIO is
 * asserted AND the lid is open.  This supports passing the backlight-enable
 * signal from the AP through EC.
 */
/*****************************************************************************/
/* Battery config */
/* Support a simple battery. */
/*
 * Compile battery-specific code.
 *
 * Note that some boards have their own unique battery constants / functions.
 * In this case, those are provided in board/(boardname)/battery.c, and none of
 * these are defined.
 */
/* Compile mock battery support; used by tests. */
/*
 * Charger should call battery_override_params() to limit/correct the voltage
 * and current requested by the battery pack before acting on the request.
 *
 * This is valid with CONFIG_CHARGER_V1 only.
 */
/*
 * If defined, the charger will check for battery presence before attempting
 * to communicate with it. This avoids the 30 second delay when booting
 * without a battery present. Do not use with CONFIG_BATTERY_PRESENT_GPIO.
 *
 * Replace the default battery_is_present() function with a board-specific
 * implementation in board.c
 */
/*
 * If defined, GPIO which is driven low when battery is present.
 * Charger will check for battery presence before attempting to communicate
 * with it. This avoids the 30 second delay when booting without a battery
 * present. Do not use with CONFIG_BATTERY_PRESENT_CUSTOM.
 */
/*
 * Compile smart battery support
 *
 * For batteries which support this specification:
 * http://sbs-forum.org/specs/sbdat110.pdf)
 */
/*
 * Critical battery shutdown timeout (seconds)
 *
 * If the battery is at extremely low charge (and discharging) or extremely
 * high temperature, the EC will shut itself down. This defines the timeout
 * period in seconds between the critical condition being detected and the
 * EC shutting itself down. Note that if the critical condition is corrected
 * before the timeout expiration, the EC will not shut itself down.
 *
 */
/* Perform a battery cut-off when we reach the battery critical level */
/*
 * Support battery cut-off as host command and console command.
 *
 * Once defined, you have to implement a board_cut_off_battery() function
 * in board/???/battery.c file.
 */
/*
 * The default delay is 1 second. Define this if a board prefers
 * different delay.
 */
/*
 * The board-specific battery.c implements get and set functions to read and
 * write arbirary vendor-specific parameters stored in the battery.
 * See include/battery.h for prototypes.
 */
/*
 * TODO(crosbug.com/p/29467): allows charging of a dead battery that
 * requests nil for current and voltage. Remove this workaround when
 * possible.
 */
/*
 * Check for battery in disconnect state (similar to cut-off state). If this
 * battery is found to be in disconnect state, take it out of this state by
 * force-applying a charge current.
 */
/* Boot header storage offset. */
/* Size of boot header in storage. */
/*****************************************************************************/
/*
 * Call board_config_post_gpio_init() after GPIOs are initialized.  See
 * include/board_config.h for more information.
 */
/*
 * Call board_config_pre_init() before any inits are called.  See
 * include/board_config.h for more information.
 */
/* EC has GPIOs attached to board version stuffing resistors */
/* The decoding of the GPIOs defining board version is defined in board code */
/* Permanent LM4 boot configuration */
/*****************************************************************************/
/* Modify the default behavior to make system bringup easier. */
/*
 * Enable debug prints / asserts that may helpful for debugging board bring-up,
 * but probably shouldn't be enabled for production for performance reasons.
 */
/*****************************************************************************/
/*
 * Number of extra buttons not on the keyboard scan matrix. Doesn't include
 * the power button, which has its own handler.
 */
/*
 * Enable case close debug (CCD) mode.
 */
/*
 * Capsense chip has buttons, too.
 */
/*****************************************************************************/
/* Compile charge manager */
/* Allow charge manager to default to charging from dual-role partners */
/* Handle the external power limit host command in charge manager */
/* Compile input current ramping support */
/* The hardware has some input current ramping/back-off mechanism */
/*****************************************************************************/
/* Charger config */
/* Compile common charge state code. You must pick an implementation. */
/* Enable charger AMON_BMON ADC current detection */
/* Compile charger-specific code for these chargers (pick at most one) */
/*
 * BQ2589x IR Compensation settings.
 * Should be the combination of BQ2589X_IR_TREG_xxxC, BQ2589X_IR_VCLAMP_yyyMV
 * and  BQ2589X_IR_BAT_COMP_zzzMOHM.
 */
/*
 * BQ2589x 5V boost current limit and voltage.
 * Should be the combination of BQ2589X_BOOSTV_MV(voltage) and
 * BQ2589X_BOOST_LIM_xxxMA.
 */
/*
 * Board specific charging current limit, in mA.  If defined, the charge state
 * machine will not allow the battery to request more current than this.
 */
/* Enable/disable system power monitor PSYS function */
/*
 * Board specific charging current termination limit, in mA.  If defined and
 * charger supports setting termination current it should be set during charger
 * init.
 *
 * TODO(tbroch): Only valid for bq2589x currently.  Configure defaults for other
 * charger ICs that support termination currents.
 */
/*
 * Board supports discharge mode.  In this mode, the battery will discharge
 * even if AC is present.  Used for testing.
 */
/* Board has a custom discharge mode. */
/*
 * Board specific flag used to disable external ILIM pin used to determine input
 * current limit. When defined, the input current limit is decided only by
 * the software register value.
 */
/*
 * Default input current for the board, in mA.
 *
 * This value should depend on external power adapter, designed charging
 * voltage, and the maximum power of the running system. For type-C chargers,
 * this should be set to 512 mA in order to not brown-out low-current USB
 * charge ports.
 */
/*
 * Board specific maximum input current limit, in mA.
 */
/* Minimum battery percentage for power on */
/* Narrow VDC power path */
/*
 * Low energy thresholds - when battery level is below BAT_PCT and an external
 * charger provides less than CHG_MW of power, inform the AP of the situation
 * through the LIMIT_POWER host event.
 */
/*
 * Equivalent of CONFIG_BATTERY_OVERRIDE_PARAMS for use with
 * CONFIG_CHARGER_V2
 */
/* Value of the charge sense resistor, in mOhms */
/* Value of the input current sense resistor, in mOhms */
/*
 * Maximum time to charge the battery, in hours.
 *
 * If this timeout is reached, the charger will enter force-idle state.
 * If not defined, charger will provide current until the battery asks it to
 * stop.
 */
/*
 * Board has an GPIO pin to enable or disable charging.
 *
 * This GPIO should be named GPIO_CHARGER_EN, if active high. Or
 * GPIO_CHARGER_EN_L if active low.
 */
/* Charger enable GPIO is active low */
/* Enable trickle charging */
/*****************************************************************************/
/* Chipset config */
/* AP chipset support; pick at most one */
/* Support chipset throttling */
/* Enable additional chipset debugging */
/* Support power rail control */
/*****************************************************************************/
/*
 * Chip config for clock circuitry
 *	define = crystal / undef = oscillator
 */
/*****************************************************************************/
/* PMIC config */
/* Support firmware long press power-off timer */
/* Support PMIC power control */
/*****************************************************************************/
/*
 * Optional console commands
 *
 * Defining these options will enable the corresponding command on the EC
 * console.
 */
/*****************************************************************************/
/* Provide common core code to output panic information without interrupts. */
/*
 * Store a panic log and halt the system for a software-related reasons, such as
 * stack overflow or assertion failure.
 */
/*
 * Provide the default GPIO abstraction layer.
 * You want this unless you are doing a really tiny firmware.
 */
/*
 * Provides smaller GPIO names to reduce flash size.  Instead of the 'name'
 * field in GPIO macro it will concat 'port' and 'pin' to reduce flash size.
 */
/*
 * Provide common runtime layer code (tasks, hooks ...)
 * You want this unless you are doing a really tiny firmware.
 */
/* Provide common core code to handle the operating system timers. */
/*****************************************************************************/
/*
 * Provide additional help on console commands, such as the supported
 * options/usage.
 *
 * Boards may #undef this to reduce image size.
 */
/*
 * Number of entries in console history buffer.
 *
 * Boards may #undef this to reduce memory usage.
 */
/* Max length of a single line of input */
/*
 * Disable EC console input if the system is locked.  This is needed for
 * security on platforms where the EC console is accessible from outside the
 * case - for example, via a special USB dongle.
 */
/*
 * Enable the experimental console.
 *
 * NOTE: If you enable this experimental console, you will need to run the
 * EC-3PO interactive console in the util directory!  Otherwise, you won't be
 * able to enter any commands.
 */
/* Include CRC-8 utility function */
/*
 * When enabled, do not build RO image from the same set of files as the RW
 * image. Instead define a separate set of object files in the respective
 * build.mk files by adding the objects to the custom-ro_objs-y variable.
 */
/*
 * When enabled, build in support for hardware crypto; only supported on CR50.
 */
/*****************************************************************************/
/*
 * Debugging config
 *
 * Note that these options are enabled by default, because they're really
 * handy for debugging systems during bringup and even at factory time.
 *
 * A board may undefine any or all of these to reduce image size and RAM usage,
 * at the cost of debuggability.
 */
/*
 * ASSERT() macros are checked at runtime.  See CONFIG_DEBUG_ASSERT_REBOOTS
 * to see what happens if one fails.
 *
 * Boards may #undef this to reduce image size.
 */
/*
 * Prints a message and reboots if an ASSERT() macro fails at runtime.  When
 * enabled, an ASSERT() which fails will produce a message of the form:
 *
 * ASSERTION FAILURE '<expr>' in function() at file:line
 *
 * If this is not defined, failing ASSERT() will trigger a BKPT instruction
 * instead.
 *
 * Ignored if CONFIG_DEBUG_ASSERT is not defined.
 *
 * Boards may #undef this to reduce image size.
 */
/*
 * On assertion failure, prints only the file name and the line number.
 *
 * Ignored if CONFIG_DEBUG_ASSERT_REBOOTS is not defined.
 *
 * Boards may define this to reduce image size.
 */
/*
 * Disable the write buffer used for default memory map accesses.
 * This turns "Imprecise data bus errors" into "Precise" errors
 * in exception traces at the cost of some performance.
 * This may help identify the offending instruction causing an
 * exception. Supported on cortex-m.
 */
/*
 * Print additional information when exceptions are triggered, such as the
 * fault address, here shown as bfar. This shows the reason for the fault
 * and may help to determine the cause.
 *
 *	=== EXCEPTION: 03 ====== xPSR: 01000000 ===========
 *	r0 :0000000b r1 :00000047 r2 :60000000 r3 :200013dd
 *	r4 :00000000 r5 :080053f4 r6 :200013d0 r7 :00000002
 *	r8 :00000000 r9 :200013de r10:00000000 r11:00000000
 *	r12:00000000 sp :200009a0 lr :08002b85 pc :08003a8a
 *	Precise data bus error, Forced hard fault, Vector catch, bfar = 60000000
 *	mmfs = 00008200, shcsr = 00000000, hfsr = 40000000, dfsr = 00000008
 *
 * If this is not defined, only a register dump will be printed.
 *
 * Boards may #undef this to reduce image size.
 */
/* Support Synchronous UART debug printf. */
/* Check for stack overflows on every context switch */
/*****************************************************************************/
/* Support DMA transfers inside the EC */
/* Use the common interrupt handlers for DMA IRQs */
/* Compile extra debugging and tests for the DMA module */
/* Support EC to Internal bus bridge. */
/* Support EC chip internal data EEPROM */
/* Include code for handling external power */
/* Support detecting external power presence via a GPIO */
/*****************************************************************************/
/* Number of cooling fans. Undef if none. */
/*
 * Replace the default fan_percent_to_rpm() function with a board-specific
 * implementation in board.c
 */
/*
 * We normally check and update the fans once per second (HOOK_SECOND). If this
 * is #defined to a postive integer N, we will only update the fans every N
 * seconds instead.
 */
/*****************************************************************************/
/* Flash configuration */
/* Support programming on-chip flash */
/* Base address of program memory */
/*
 * EC code can reside on internal or external storage. Only one of these
 * CONFIGs should be defined.
 */
/*
 * Flash is directly mapped into the EC's address space.  If this is not
 * defined, the flash driver must implement flash_physical_read().
 */
/*
 * Base address of memory-mapped flash storage, for platforms which define
 * CONFIG_MAPPED_STORAGE.
 */
/*
 * Store persistent write protect for the flash inside the flash data itself.
 * This allows ECs with internal flash to emulate something closer to a SPI
 * flash write protect register.  If this is not defined, write protect state
 * is maintained solely by the physical flash driver.
 */
/*
 * Store the pstate data in its own dedicated bank of flash.  This allows
 * disabling the protect-RO-at-boot flag without rewriting the RO firmware,
 * but costs a bank of flash.
 *
 * If this is not defined, the pstate data is stored inside the RO firmware
 * image itself.  This is more space-efficient, but the only way to clear the
 * flag once it's set is to rewrite the RO firmware (after removing the WP
 * screw, of course).
 */
/* Total size of writable flash */
/* Minimum flash write size (in bytes) */
/* Most efficient flash write size (in bytes) */
/* Protected region of storage belonging to EC */
/* Writable region of storage belonging to EC */
/*****************************************************************************/
/* Include a flashmap in the compiled firmware image */
/* Allow EC serial console input to wake up the EC from STOP mode */
/* Enable support for floating point unit */
/*****************************************************************************/
/* Firmware region configuration */
/*
 * Reuse the space that was occupied in RAM by the little firmware (LFW) loader
 * with the section ".bss.slow" instead.
 */
/*
 * Read-only / read-write image configuration.
 * Images may reside on storage (ex. external or internal SPI) at a different
 * offset than when copied to program memory. Hence, two sets of offsets,
 * for STORAGE and for MEMORY.
 */
/* Offset relative to CONFIG_EC_PROTECTED_STORAGE_OFF */
/* Some targets include two RW sections in the image. */
/* This is the offset of the second RW section into the flash. */
/* Offset relative to CONFIG_EC_WRITABLE_STORAGE_OFF */
/*
 * NPCX-specific bootheader geometry.
 * TODO(crosbug.com/p/23796): Factor these CONFIGs out.
 */
/*
 * Write protect region offset / size. This region normally encompasses the
 * RO image, but may also contain additional images or data.
 */
/*
 * Board Image ec.bin contains a RO firmware.  If not defined, the image will
 * only contain the RW firmware. The RO firmware comes from another board.
 */
/* If defined, another image (RW) exists with more features */
/*
 * If defined, we can use system_get_fw_reset_vector function to decide
 * reset vector of RO/RW firmware for sysjump.
 */
/*****************************************************************************/
/* Motion sensor based gesture recognition information */
/* These all require HAS_TASK_MOTIONSENSE to work */
/* Do we want to detect gestures? */
/* Mask of all sensors used for gesture dectections */
/* some gesture recognition done in software */
/* enable gesture host interface */
/* Sensor sampling interval for gesture recognition */
/* Which sensor to look for battery tap recognition */
/*
 * Double tap detection parameters
 * Double tap works by looking for two isolated Z-axis accelerometer impulses
 * preceded and followed by relatively calm periods of accelerometer motion.
 *
 * Define an outer and inner window. The inner window specifies how
 * long the tap impulse is expected to last. The outer window specifies the
 * period before the initial tap impluse and after the final tap impulse for
 * which to check for relatively calm periods. In between the two impulses
 * there is a minimum and maximum interstice time allowed.
 *
 * Define an acceleration threshold to dectect a tap, in mg.
 */
/* Event generated when battery tap is detected */
/* Which sensor to look for significant motion activity */
/*
 * Significant motion parameters
 * Sigmo state machine looks for movement, waits skip milli-seconds,
 * and check for movement again with proof milli-seconds.
 */
/* Event generated when significant motion is detected. */
/* Do we want to detect the lid angle? */
/* Which sensor is located on the base? */
/* Which sensor is located on the lid? */
/*
 * Allows using the lid angle measurement to determine if peripheral devices
 * should be enabled or disabled, like key scanning, trackpad interrupt.
 */
/* Define which index in motion_sensors is in the base. */
/* Define which index in motion_sensors is in the lid. */
/******************************************************************************/
/* Host to RAM (H2RAM) Memory Mapping */
/* H2RAM Base memory address */
/* H2RAM Size */
/* H2RAM Host LPC I/O base memory address */
/*
 * Define the minimal amount of time (in ms) betwen running motion sense task
 * loop.
 */
/*****************************************************************************/
/*
 * Support the host asking the EC about the status of the most recent host
 * command.
 *
 * When the AP is attached to the EC via a serialized bus such as I2C or SPI,
 * it needs a way to minimize the length of time an EC command will tie up the
 * bus (and the kernel driver on the AP).  If this config is defined, the EC
 * may return an in-progress result code for slow commands such as flash
 * erase/write instead of stalling until the command finishes processing, and
 * the AP may then inquire the status of the current command and/or the result
 * of the previous command.
 */
/* If we have host command task, assume we also are using host events. */
/*
 * For ECs where the host command interface is I2C, slave
 * address which the EC will respond to.
 */
/*
 * Accept EC host commands over the SPI slave (SPS) interface.
 */
/*
 * Host command rate limiting assures EC will have time to process lower
 * priority tasks even if the AP is hammering the EC with host commands.
 * If there is less than CONFIG_HOSTCMD_RATE_LIMITING_MIN_REST between
 * host commands for CONFIG_HOSTCMD_RATE_LIMITING_PERIOD, then a
 * recess period of CONFIG_HOSTCMD_RATE_LIMITING_RECESS will be
 * enforced.
 */
/* PD MCU supports host commands */
/*
 * Use if PD MCU controls charging (selecting charging port and input
 * current limit).
 */
/* Panic when status of PD MCU reflects that it has crashed */
/*****************************************************************************/
/* Enable debugging and profiling statistics for hook functions */
/*****************************************************************************/
/* CRC configuration */
/* Enable the hardware accelerator for CRC computation */
/* Enable the software routine for CRC computation */
/*****************************************************************************/
/* Enable system hibernate */
/* Default delay after shutting down before hibernating */
/*
 * Use to define going in to hibernate early if low on battery.
 * CONFIG_HIBERNATE_BATT_PCT specifies the low battery threshold
 * for going into hibernate early, and CONFIG_HIBERNATE_BATT_SEC defines
 * the minimum amount of time to stay in G3 before checking for low
 * battery hibernate.
 */
/*
 * Perform a system reset on wake from hibernate. This is the default behavior,
 * and the only chip-supported behavior for certain ECs.
 */
/* For ECs with multiple wakeup pins, define enabled wakeup pins */
/* Use a hardware specific udelay(). */
/*****************************************************************************/
/* I2C configuration */
/* EC uses an I2C master interface */
/* EC uses an I2C slave interface */
/* Defines I2C operation retry count when slave nack'd(EC_ERROR_BUSY) */
/*
 * I2C SCL gating.
 *
 * If CONFIG_I2C_SCL_GATE_ADDR/PORT is defined, whenever the defined address
 * is addressed, CONFIG_I2C_SCL_GATE_GPIO is set to high. When the I2C
 * transaction is done, the pin is set back to low.
 */
/*
 * I2C multi-port controller.
 *
 * If CONFIG_I2C_MULTI_PORT_CONTROLLER is defined, a single on-chip I2C
 * controller may have multiple I2C ports attached. Therefore, I2c operations
 * must lock the controller (not just the port) to prevent hardware access
 * conflicts.
 */
/*****************************************************************************/
/* Current/Power monitor */
/*
 * Compile driver for INA219 or INA231. These two flags may not be both
 * defined.
 */
/*****************************************************************************/
/* Inductive charging */
/* Enable inductive charging support */
/******************************************************************************/
/* Support NXP PCA9534 I/O expander. */
/*****************************************************************************/
/* Number of IRQs supported on the EC chip */
/*
 * This is the block size of the ILM on the it839x chip.
 * The ILM for static code cache, CPU fetch instruction from
 * ILM(ILM -> CPU)instead of flash(flash -> IMMU -> CPU) if enabled.
 */
/* Enable Wake-up control interrupt from KSI */
/* LPC cycle can wake-up EC from doze / deep doze mode if define it. */
/* Interrupt for PECI module. (IT839X series and IT838X DX only) */
/* Allow the host access to the PNPCFG registers */
/* To define it, if I2C channel C and PECI used at the same time. */
/*****************************************************************************/
/* Keyboard config */
/*
 * The Silego reset chip sits in between the EC and the physical keyboard on
 * column 2.  To save power in low-power modes, some Silego variants require
 * the signal to be inverted so that the open-drain output from the EC isn't
 * costing power due to the pull-up resistor in the Silego.
 */
/*
 * Config KSO to start from a different KSO pin. This is to allow some chips
 * to use alternate functions on KSO pins.
 */
/* Enable extra debugging output from keyboard modules */
/* The board uses a negative edge-triggered GPIO for keyboard interrupts. */
/* Compile code for 8042 keyboard protocol */
/* Compile code for MKBP keyboard protocol */
/*
 * Keyboard config (struct keyboard_scan_config) is in board.c.  If this is
 * not defined, default values from common/keyboard_scan.c will be used.
 */
/*
 * Minimum CPU clocks between scans.  This ensures that keyboard scanning
 * doesn't starve the other EC tasks of CPU when running at a decreased system
 * clock.
 */
/*
 * Call board-supplied keyboard_suppress_noise() function when the debounced
 * keyboard state changes.  Some boards use this to send a signal to the audio
 * codec to suppress typing noise picked up by the microphone.
 */
/*
 * Enable keyboard testing functionality. This enables a message which receives
 * a list of keyscan events from the AP and processes them.  This will cause
 * keypresses to appear on the AP through the same mechanism as a normal
 * keyboard press.
 *
 * This can be used to spoof keyboard events, so is not normally defined,
 * except during internal testing.
 */
/*****************************************************************************/
/* Support common LED interface */
/* Standard LED behavior according to spec given that we have a red-green
 * bicolor led for charging and one power led
 */
/*
 * LEDs for LED_POLICY STD may be inverted.  In this case they are active low
 * and the GPIO names will be GPIO_LED..._L.
 */
/* Support for LED driver chip(s) */
/* Offset in flash where little firmware will live. */
/*
 * Compile lid switch support.
 *
 * This is enabled by default because all boards other than reference boards
 * are for laptops with lid switchs.  Reference boards #undef it.
 */
/*
 * GPIOs to use to detect that the lid is opened.
 *
 * This is a X-macro composed of a list of LID_OPEN(GPIO_xxx) elements defining
 * all the GPIOs to check to find whether the lid is currently opened.
 * If not defined, it is using GPIO_LID_OPEN.
 */
/*
 * Support for turning the lightbar power rails on briefly when the AP is off.
 * Enabling this requires implementing the board-specific lb_power() function
 * to do it (see lb_common.h).
 */
/*
 * For tap sequence, show the last segment in dim to give a better idea of
 * battery percentage.
 */
/* Program memory offset for little firmware loader. */
/* Size of little firmware loader. */
/* Little firmware loader storage offset. */
/*
 * Low power idle options. These are disabled by default and all boards that
 * want to use low power idle must define it. When using the LFIOSC, the low
 * frequency clock will be used to conserve even more power when possible.
 *
 * GPIOs which need to trigger interrupts in low power idle must specify the
 * GPIO_INT_DSLEEP flag in gpio_list[].
 *
 * Note that for some processors (e.g. LM4), an active JTAG connection will
 * prevent the EC from using low-power idle.
 */
/*
 * Enable Pseudo G3 (power removed from EC)
 * This requires board specific implementation.
 */
/*
 * Enable deep sleep during S0 (ignores SLEEP_MASK_AP_RUN).
 */
/* Support LPC interface */
/* Base address of low power RAM. */
/* Size of low power RAM. */
/* Use Link-Time Optimizations to try to reduce the firmware code size */
/* Need for a math library */
/* Include code to do online compass calibration */
/* Presence of a Bosh Sensortec BMM150 magnetometer behind a BMI160. */
/* Microchip EC SRAM start address */
/* Microchip EC SRAM end address */
/* Microchip EC SRAM size */
/*
 * Define Megachips DisplayPort to HDMI protocol converter/level shifter serial
 * interface.
 */
/* Define clock input to MFT module. */
/* Support MKBP event */
/*
 * With this option, we can define the MKBP wakeup events in this mask (as a
 * white list) in board level, those events allow to interrupt AP during S3.
 */
/* Support memory protection unit (MPU) */
/* Support one-wire interface */
/* Support PECI interface to x86 processor */
/*
 * Maximum operating temperature in degrees Celcius used on some x86
 * processors. CPU chip temperature is reported relative to this value and
 * is never reported greater than this value. Processor asserts PROCHOT#
 * and starts throttling frequency and voltage at this temp. Operation may
 * become unreliable if temperature exceeds this limit.
 */
/*****************************************************************************/
/* PMU config */
/*
 * Enable hard-resetting the PMU from the EC.  The implementation is rather
 * hacky; it simply shorts out the 3.3V rail to force the PMIC to panic.  We
 * need this unfortunate hack because it's the only way to reset the I2C engine
 * inside the PMU.
 */
/* Support TPS65090 PMU */
/* Suport TPS65090 PMU charging LED. */
/*
 * Support PMU powerinfo host and console commands.  Note that the
 * implementation is currently specific to the Pit board, so don't blindly
 * enable this for another board without fixing that first.
 */
/*
 * Enable this config to make console UART self sufficient (no other
 * initialization required before uart_init(), no interrupts, uart_tx_char()
 * does not exit until character finished transmitting).
 *
 * This is useful during early hardware bringup, each platform needs to
 * implement its own code to support this.
 */
/* Compile common code to support power button debouncing */
/* Force the active state of the power button : 0(default if unset) or 1 */
/* Allow the power button to send events while the lid is closed */
/* Support sending the power button signal to x86 chipsets */
/* Compile common code for AP power state machine */
/* Disable the power-on transition when the lid is opened */
/* Support stopping in S5 on shutdown */
/*
 * Detect power signal interrupt storms, defined as more than
 * CONFIG_POWER_SIGNAL_INTERRUPT_STORM_DETECT_THRESHOLD occurences of a single
 * power signal interrupt within one second.
 */
/* Use part of the EC's data EEPROM to hold persistent storage for the AP. */
/* Support S0ix */
/*****************************************************************************/
/* Support PWM control */
/* Support PWM control while in low-power idle */
/* Define clock input to PWM module. */
/*****************************************************************************/
/* Support PWM output to keyboard backlight */
/* Base address of RAM for the chip */
/* Size of RAM available on the chip, in bytes */
/* Support IR357x Link voltage regulator debugging / reprogramming */
/* Support verifying 2048-bit RSA signature */
/* Define the RSA key size. */
/*
 * Verify the RW firmware using the RSA signature.
 * (for accessories without software sync)
 */
/*
 * By default the pubkey and sig are put at the end of the first and second
 * half of the total flash, and take up the minimum space possible. You can
 * override those defaults with these.
 */
/****************************************************************************/
/* Shared objects library. */
/* Support shared objects library between RO and RW. */
/* Size of shared objects library. */
/* Program memory offset of shared objects library. */
/* Storage  offset of sharedobjects library. */
/*
 * If defined, the hash module will save its last computed hash when jumping
 * between EC images.
 */
/* Enable smart battery firmware update driver */
/* Allow the board to use a GPIO for the SCI# signal. */
/* Support computing SHA-1 hash */
/* Support computing of other hash sizes (without the VBOOT code) */
/* Emulate the CLZ (Count Leading Zeros) in software for CPU lacking support */
/* Support smbus interface */
/* Support SPI interfaces */
/* Support deprecated SPI protocol version 2. */
/*
 * Support SPI Slave interfaces. The first board supporting this is cr50 and
 * in its parlance SPI_SLAVE is called SPS. This convention might be
 * reconsidered later, and the use of "SPI" in different config options needs
 * to be cleand up. (crbug.com/512613).
 */
/* Define the SPI port to use to access SPI accelerometer */
/* Support SPI flash */
/* Define the SPI port to use to access the flash */
/* Support W25Q64 SPI flash */
/* Support W25X40 SPI flash */
/* Support GD25Q41B SPI flash */
/* SPI flash part supports SR2 register */
/* SPI master feature */
/* Support SPI masters without GPIO-specified Chip Selects, instead rely on the
 * SPI master port's hardwired CS pin. */
/* Support testing SPI slave controller driver. */
/* Default stack size to use for tasks, in bytes */
/* Use 32-bit timer for clock source on stm32. */
/* Fake hibernate mode */
/*
 * Compile common code to handle simple switch inputs such as the recovery
 * button input from the servo debug interface.
 */
/* Support dedicated recovery signal from servo board */
/*
 * System should remain unlocked even if write protect is enabled.
 *
 * NOTE: This should ONLY be defined during bringup, and should never be
 * defined on a shipping / released platform.
 */
/*****************************************************************************/
/* Task config */
/*
 * List of enabled tasks in ascending priority order.  This is normally
 * defined in each board's ec.tasklist file.
 *
 * For each task, use the macro TASK_ALWAYS(n, r, d, s) for base tasks and
 * TASK_NOTEST(n, r, d, s) for tasks that can be excluded in test binaries,
 * where :
 * 'n' is the name of the task
 * 'r' is the main routine of the task
 * 'd' is an opaque parameter passed to the routine at startup
 * 's' is the stack size in bytes; must be a multiple of 8
 */
/*
 * List of test tasks.  Same format as CONFIG_TASK_LIST, but used to define
 * additional tasks for a unit test.  Normally defined in
 * test/{testname}.tasklist.
 */
/*
 * Enable task profiling.
 *
 * Boards may #undef this to reduce image size and RAM usage.
 */
/*****************************************************************************/
/* Temperature sensor config */
/* Compile common code for temperature sensor support */
/* Support particular temperature sensor chips */
/*
 * If defined, active-high GPIO which indicates temperature sensor chips are
 * powered.  If not defined, temperature sensors are assumed to be always
 * powered.
 */
/*****************************************************************************/
/* TPM-like configuration */
/* Speak the TPM SPI Hardware Protocol on the SPI slave interface */
/*****************************************************************************/
/* USART stream config */
/*
 * Each USART stream can be individually enabled and accessible using the
 * stream interface provided in the usart_config struct.
 */
/*****************************************************************************/
/* USB stream config */
/*****************************************************************************/
/* UART config */
/* Baud rate for UARTs */
/* UART index (number) for EC console */
/* UART index (number) for host UART, if present */
/* Use uart_input_filter() to filter UART input. See prototype in uart.h */
/*
 * UART receive buffer size in bytes.  Must be a power of 2 for macros in
 * common/uart_buffering.c to work properly.  Must be larger than
 * CONFIG_CONSOLE_INPUT_LINE_SIZE to copy and paste scripts.
 */
/* Use DMA for UART input */
/*
 * On some platforms, UART receive DMA can't trigger an interrupt when a single
 * character is received.  Those platforms poll for characters every HOOK_TICK.
 * When a character is received, make this many additional checks between then
 * and the next HOOK_TICK, to increase responsiveness of the console to input.
 */
/*
 * UART transmit buffer size in bytes.  Must be a power of 2 for macros in
 * common/uart_buffering.c to work properly.
 */
/* Use DMA for UART output */
/* The DMA channel for UART.  If not defined, default to UART1. */
/*****************************************************************************/
/* USB PD config */
/* Include all USB Power Delivery modules */
/* Support for USB PD alternate mode */
/* Support for USB PD alternate mode of Downward Facing Port */
/* Check if max voltage request is allowed before each request */
/* Default state of PD communication enabled flag */
/* Respond to custom vendor-defined messages over PD */
/* Default USB data role when a USB PD debug accessory is seen */
/* Define if this board can act as a dual-role PD port (source and sink) */
/* Dynamic USB PD source capability */
/* Support USB PD flash. */
/* Check whether PD is the sole power source before flash erase operation */
/* Major and Minor ChromeOS specific PD device Hardware IDs. */
/* HW & SW version for alternate mode discover identity response (4bits each) */
/* USB PD MCU slave address for host commands */
/* Define if using internal comparator for PD receive */
/* Record main PD events in a circular buffer */
/* The size in bytes of the FIFO used for PD events logging */
/* Save power by waking up on VBUS rather than polling CC */
/* Allow chip to go into low power idle even when a PD device is attached */
/* Define if USB-PD device has no way of detecting USB VBUS */
/* Number of USB PD ports */
/* Simple DFP, such as power adapter, will not send discovery VDM on connect */
/* Use comparator module for PD RX interrupt */
/* Use TCPC module (type-C port controller) */
/*
 * Choose one of the following TCPMs (type-C port manager) to manage TCPC. The
 * TCPM stub is used to make direct function calls to TCPC when TCPC is on
 * the same MCU. The TCPCI TCPM uses the standard TCPCI i2c interface to TCPC.
 */
/*
 * Use this option if the TCPC port controller is on a seperate chip from
 * the TCPM layer and if VUBS detect GPIO is not available on the TCPM
 * mcu.
 */
/* Define the type-c port controller I2C base address. */
/* Use this option to enable Try.SRC mode for Dual Role devices */
/* Set the default minimum battery percentage for Try.Src to be enabled */
/* Alternative configuration keeping only the TX part of PHY */
/* Use DAC as reference for comparator at 850mV. */
/* USB Product ID. */
/* Support for USB type-c superspeed mux */
/*
 * Only configure USB type-c superspeed mux when DFP (for chipsets that
 * don't support being a UFP)
 */
/* Sniffer header version
 * Version 1: [timestamp:2B, sequence number:2B]
 * Version 2: [timestamp:2B, sequence number:2B,
 *             Vbus value: 2B, vbus timestamp offset: 2B]
 */
/* Support v1.1 type-C connection state machine */
/* Support for USB type-c vconn. Not needed for captive cables. */
/* Support VCONN swap */
/* USB Binary device Object Store support */
/* USB Device version of product */
/*****************************************************************************/
/* Compile chip support for the USB device controller */
/* Support USB blob handler. */
/* Common USB / BC1.2 charger task */
/* Enable USB serial console module. */
/* Support USB HID interface. */
/* USB device buffers and descriptors */
/* Disable automatic connection of USB peripheral */
/* Disable automatic initialization of USB peripheral */
/* Support simple control of power to the device's USB ports */
/*
 * Support supplying USB power in S3, if the host leaves the port enabled when
 * entering S3.
 */
/*
 * Support smart power control to the device's USB ports, using
 * dedicated power control chips.  This potentially enables automatic
 * negotiation of supplying more power to peripherals.
 */
/*
 * Override the default charging mode for USB smart power control.
 * Value is selected from usb_charge_mode in include/usb_charge.h
 */
/*
 * Smart USB power control can use a full set of control signals to the USB
 * port power chip, or a reduced set.  If this is defined, use the reduced set.
 */
/*
 * Smart USB power control current limit pins may be inverted.  In this case
 * they are active low and the GPIO names will be GPIO_USBn_ILIM_SEL_L.
 */
/******************************************************************************/
/* USB port switch */
/* 8-bit USB type-C switch I2C addresses */
/* Support the TSU6721 I2C smart switch */
/* Support the Pericom PI3USB9281 I2C USB switch */
/* Number of Pericom PI3USB9281 chips present in system */
/* Support the Pericom PI3USB30532 USB3.0/DP1.2 Matrix Switch */
/* Support the Parade PS8740 Type-C Redriving Switch */
/*****************************************************************************/
/* USB GPIO config */
/*****************************************************************************/
/* USB SPI config */
/*****************************************************************************/
/* Support computing hash of code for verified boot */
/*****************************************************************************/
/* Watchdog config */
/*
 * Compile watchdog timer support.  The watchdog timer will reboot the system
 * if the hook task (which is the lowest-priority task on the system) gets
 * starved for CPU time and isn't able to fire its HOOK_TICK event.
 */
/*
 * Try to detect a watchdog that is about to fire, and print a trace.  This is
 * required on chips such as STM32 where the watchdog timer simply reboots the
 * system without any early warning.
 */
/* Watchdog period in ms; see also AUX_TIMER_PERIOD_MS */
/*
 * Fire auxiliary timer 500ms before watchdog timer expires. This leaves
 * some time for debug trace to be printed.
 */
/*****************************************************************************/
/*
 * Support controlling power to WiFi, WWAN (3G/LTE), and/or bluetooth modules.
 */
/*
 * Support for WiFi devices that must remain powered in suspend.  Set to the
 * combination of EC_WIRELESS_SWITCH flags (from ec_commands.h) which should
 * be set in suspend.
 */
/*
 * Write protect signal is active-high.  If this is defined, there must be a
 * GPIO named GPIO_WP; if not defined, there must be a GPIO names GPIO_WP_L.
 */
/*
 * The write protect signal is always asserted,
 * independantly of the GPIO existence or current value.
 */
/*
 * If needed to allocate some free space in the base of the RO or RW section
 * of the image, define these to be equal the required size of the free space.
 */
/*****************************************************************************/
/*
 * Include board and core configs, since those hold the CONFIG_ constants for a
 * given configuration.  This guarantees they get included everywhere, and
 * fixes a fairly common bug where we gate out code with #ifndef
 * CONFIG_SOMETHING and but forget to include both of these.
 *
 * Board is included after chip, so that chip defaults can be overridden on a
 * per-board basis as needed.
 */
/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* CPU core BFD configuration */
/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Linker binary architecture and format */
/* 16.000 Mhz internal oscillator frequency (PIOSC) */
/* Number of IRQ vectors on the NVIC */
/* Use a bigger console output buffer */
/* Interval between HOOK_TICK notifications */
/* Maximum number of deferrable functions */
/* Number of I2C ports */
/*
 * Time it takes to set the RTC match register. This value is conservatively
 * set based on measurements around 200us.
 */
/****************************************************************************/
/* Memory mapping */
/* System stack size */
/* non-standard task stack sizes */
/* Default task stack size */
/* Ideal flash write size fills the 32-entry flash write buffer */
/* This is the physical size of the flash on the chip. We'll reserve one bank
 * in order to emulate per-bank write-protection UNTIL REBOOT. The hardware
 * doesn't support a write-protect pin, and if we make the write-protection
 * permanent, it can't be undone easily enough to support RMA. */
/****************************************************************************/
/* Define our flash layout. */
/* Memory-mapped internal flash */
/* Program is run directly from storage */
/* Compute the rest of the flash params from these */
/* Copyright 2015 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/*
 * Standard memory-mapped flash layout:
 * - RO image starts at the beginning of flash.
 * - PSTATE immediately follows the RO image.
 * - RW image starts at the second half of flash.
 * - Protected region consists of the first half of flash (RO image + PSTATE).
 * - Unprotected region consists of second half of flash (RW image).
 *
 *                            PSTATE
 *                              |
 *                              v
 * |<-----Protected Region------>|<------Unprotected Region----->|
 * |<--------RO image--------->| |<----------RW image----------->|
 * 0                            N/2                              N
 *
 * This layout is used by several supported chips. Chips which do not use
 * this layout MUST NOT include this header file, and must instead define
 * the configs below in a chip-level header file (config_flash_layout.h).
 *
 * See the following page for additional image geometry discussion:
 *
 * https://www.chromium.org/chromium-os/ec-development/ec-image-geometry-spec
 *
 * TODO(crosbug.com/p/23796): Finish implementing the spec.
 */
/*
 * Size of one firmware image in flash - half for RO, half for RW.
 * This is NOT a globally defined config, and is only used in this file
 * for convenience.
 */
/*
 * The EC uses the one bank of flash to emulate a SPI-like write protect
 * register with persistent state.
 */
/*
 * By default, there is no shared objects library.  However, if configured, the
 * shared objects library will be placed after the RO image.
 */
/****************************************************************************/
/* Lock the boot configuration to prevent brickage. */
/*
 * No GPIO trigger for ROM bootloader.
 * Keep JTAG debugging enabled.
 * Use 0xA442 flash write key.
 * Lock it this way.
 */
/****************************************************************************/
/* Customize the build */
/* Optional features present on this chip */
/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Configuration for Samus mainboard */
/* Debug features */
/* Optional features */
/* Note: not CONFIG_BACKLIGHT_LID. It's handled specially for Samus. */
/* TODO(crosbug.com/p/29467): remove this workaround when possible. */
/* Do we want EC_WIRELESS_SWITCH_WWAN as well? */
/******************************************************************************/
/*
 * Disable the built-in console history if using the experimental console.
 *
 * The experimental console keeps its own session-persistent history which
 * survives EC reboot.  It also requires CRC8 for command integrity.
 */
/*****************************************************************************/
/*
 * Handle task-dependent configs.
 *
 * This prevent sub-modules from being compiled when the task and parent module
 * are not present.
 */
/*****************************************************************************/
/*
 * Apply test config overrides last, since tests need to override some of the
 * config flags in non-standard ways to mock only parts of the system.
 */
/* Copyright (c) 2013 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Per-test config flags */
/* Test config flags only apply for test builds */
/*
 * Sanity checks to make sure some of the configs above make sense.
 */
/* Copyright (c) 2014 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/* Copyright (c) 2014 The Chromium OS Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */
/*
 * config.h - Top-level configuration Chrome EC
 *
 * All configuration settings (CONFIG_*) are defined in this file or in a
 * sub-configuration file (config_chip.h, board.h, etc.) included by this file.
 *
 * Note that this file is included by assembly (.S) files.  Any C-isms such as
 * struct definitions or enums in a sub-configuration file MUST be guarded with
 * #ifndef __ASSEMBLER__ to prevent those C-isms from being evaluated by the
 * assembler.
 */
/*
 * The signer puts the public key and signature into the RO and RW images
 * (respectively) at known locations after the complete image is assembled. But
 * since we compile the RO & RW images separately, the other image's addresses
 * can't be computed by the linker. So we just hardcode the addresses here.
 * These can be overridden in board.h files if desired.
 */
/* The pubkey goes at the end of the first half of flash */
/* The signature goes at the end of the second half of flash */
OUTPUT_FORMAT("elf32-littlearm", "elf32-littlearm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(reset)
MEMORY
{
    FLASH (rx) : ORIGIN = (0x00000000 + (0)), LENGTH = (((0x00040000 - 0) / 2) - 0x00000800)
    IRAM (rw) : ORIGIN = 0x20000000, LENGTH = 0x00008000
}
SECTIONS
{
    .text : {
        build/samus/RO/core/cortex-m/init.o (.text.vecttable)
        . = ALIGN(4);
        __version_struct_offset = .;
        KEEP(*(.rodata.ver))
        . = ALIGN(4);
        KEEP(*(.rodata.pstate))
        . = ALIGN(4);
        build/samus/RO/core/cortex-m/init.o (.text)
        *(.text*)
    } > FLASH
    . = ALIGN(4);
    .rodata : {
 /* Symbols defined here are declared in link_defs.h */
        __irqprio = .;
        KEEP(*(.rodata.irqprio))
        __irqprio_end = .;
        . = ALIGN(4);
        __cmds = .;
        KEEP(*(SORT(.rodata.cmds*)))
        __cmds_end = .;
        . = ALIGN(4);
        __extension_cmds = .;
        KEEP(*(.rodata.extensioncmds))
 __extension_cmds_end = .;
        . = ALIGN(4);
        __hcmds = .;
        KEEP(*(.rodata.hcmds))
        __hcmds_end = .;
 . = ALIGN(4);
 __mkbp_evt_srcs = .;
 KEEP(*(.rodata.evtsrcs))
 __mkbp_evt_srcs_end = .;
        . = ALIGN(4);
        __hooks_init = .;
        KEEP(*(.rodata.HOOK_INIT))
        __hooks_init_end = .;
        __hooks_pre_freq_change = .;
        KEEP(*(.rodata.HOOK_PRE_FREQ_CHANGE))
        __hooks_pre_freq_change_end = .;
        __hooks_freq_change = .;
        KEEP(*(.rodata.HOOK_FREQ_CHANGE))
        __hooks_freq_change_end = .;
        __hooks_sysjump = .;
        KEEP(*(.rodata.HOOK_SYSJUMP))
        __hooks_sysjump_end = .;
        __hooks_chipset_pre_init = .;
        KEEP(*(.rodata.HOOK_CHIPSET_PRE_INIT))
        __hooks_chipset_pre_init_end = .;
        __hooks_chipset_startup = .;
        KEEP(*(.rodata.HOOK_CHIPSET_STARTUP))
        __hooks_chipset_startup_end = .;
        __hooks_chipset_resume = .;
        KEEP(*(.rodata.HOOK_CHIPSET_RESUME))
        __hooks_chipset_resume_end = .;
        __hooks_chipset_suspend = .;
        KEEP(*(.rodata.HOOK_CHIPSET_SUSPEND))
        __hooks_chipset_suspend_end = .;
        __hooks_chipset_shutdown = .;
        KEEP(*(.rodata.HOOK_CHIPSET_SHUTDOWN))
        __hooks_chipset_shutdown_end = .;
        __hooks_ac_change = .;
        KEEP(*(.rodata.HOOK_AC_CHANGE))
        __hooks_ac_change_end = .;
        __hooks_lid_change = .;
        KEEP(*(.rodata.HOOK_LID_CHANGE))
        __hooks_lid_change_end = .;
        __hooks_pwrbtn_change = .;
        KEEP(*(.rodata.HOOK_POWER_BUTTON_CHANGE))
        __hooks_pwrbtn_change_end = .;
        __hooks_charge_state_change = .;
        KEEP(*(.rodata.HOOK_CHARGE_STATE_CHANGE))
        __hooks_charge_state_change_end = .;
        __hooks_battery_soc_change = .;
        KEEP(*(.rodata.HOOK_BATTERY_SOC_CHANGE))
        __hooks_battery_soc_change_end = .;
        __hooks_tick = .;
        KEEP(*(.rodata.HOOK_TICK))
        __hooks_tick_end = .;
        __hooks_second = .;
        KEEP(*(.rodata.HOOK_SECOND))
        __hooks_second_end = .;
        __deferred_funcs = .;
        KEEP(*(.rodata.deferred))
        __deferred_funcs_end = .;
        __usb_desc = .;
        KEEP(*(.rodata.usb_desc_conf))
        KEEP(*(SORT(.rodata.usb_desc*)))
        __usb_desc_end = .;
        . = ALIGN(4);
        KEEP(*(.rodata.usb_ep))
        . = ALIGN(4);
        *(.rodata*)
        . = ALIGN(64);
        KEEP(*(.google))
        . = ALIGN(4);
    } > FLASH
    __ro_end = . ;
    __deferred_funcs_count =
  (__deferred_funcs_end - __deferred_funcs) / 4;
    ASSERT(__deferred_funcs_count <= 10,
           "Increase DEFERRABLE_MAX_COUNT")
    .bss : {
 /*
	 * Align to 512 bytes. This is convenient when some memory block
	 * needs big alignment. This is the beginning of the RAM, so there
	 * is usually no penalty on aligning this.
	 */
        . = ALIGN(512);
        __bss_start = .;
 *(.bss.big_align)
 /* Stacks must be 64-bit aligned */
        . = ALIGN(8);
        *(.bss.system_stack)
 /* Rest of .bss takes care of its own alignment */
        *(.bss)
    } > IRAM
    .bss.slow : {
 /* Region of RAM reclaimed from the little firmware(LFW). */
 *(.bss.slow)
 /*
	 * Not replacing the loader, so .bss.slow is part of .bss.  It needs to
	 * be followed by __bss_end so that .bss.slow will be zeroed by init.
	 */
        . = ALIGN(4);
        __bss_end = .;
    } > IRAM
    .data : AT(ADDR(.rodata) + SIZEOF(.rodata)) {
        . = ALIGN(4);
        __data_start = .;
        *(.data.tasks)
        *(.data)
        /* It has to be aligned by 32 bytes to be a valid MPU region. */
        . = ALIGN(32);
        __iram_text_start = .;
        *(.iram.text)
        . = ALIGN(32);
        __iram_text_end = .;
        __data_end = .;
 /* Shared memory buffer must be at the end of preallocated RAM, so it
	 * can expand to use all the remaining RAM. */
 __shared_mem_buf = .;
 /* Tag at end of firmware image so that we can find the image size.
	 * This may be overwritten by the shared memory buffer; that's ok
	 * because we only use it to find the image size in flash. */
        . = ALIGN(4);
        BYTE(0x45);
        BYTE(0x4e);
        BYTE(0x44);
        BYTE(0xea);
 /* NOTHING MAY GO AFTER THIS! */
    } > IRAM
    /* The linker won't notice if the .data section is too big to fit,
     * apparently because we're sending it into IRAM, not FLASH. The following
     * symbol isn't used by the code, but running "objdump -t *.elf | grep hey"
     * will let us check how much flash space we're actually using. The
     * explicit ASSERT afterwards will cause the linker to abort if we use too
     * much. */
    __hey_flash_used = LOADADDR(.data) + SIZEOF(.data) - (0x00000000 + (0));
    ASSERT(((((0x00040000 - 0) / 2) - 0x00000800)
        ) >= (LOADADDR(.data) + SIZEOF(.data) - (0x00000000 + (0))),
                 "No room left in the flash")
    /DISCARD/ : { *(.ARM.*) }
}

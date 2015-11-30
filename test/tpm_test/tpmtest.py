#!/usr/bin/python
# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Module for testing TPM, using both conventional and extended commands."""

from __future__ import print_function

import os
import struct
import sys
import traceback
import xml.etree.ElementTree as ET

# Suppressing pylint warning about an import not at the top of the file. The
# path needs to be set *before* the last import.
# pylint: disable=C6204
root_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
sys.path.append(os.path.join(root_dir, '..', '..', 'build', 'tpm_test'))
import ftdi_spi_tpm

# Basic crypto operations
DECRYPT = 0
ENCRYPT = 1

# Extension command for dcypto testing
EXT_CMD = 0xbaccd00a

# Extension subcommands for encryption types
AES = 0

if hasattr(sys.stdout, 'isatty') and sys.stdout.isatty():
  cursor_back = '\x1b[1D'  # Move one space to the left.
else:
  cursor_back = ''


class TpmError(Exception):
  pass


class TPM(object):
  """TPM accessor class.

  Object of this class allows to send valid and extended TPM commands (using
  the command() method. The wrap_command/unwrap_response methods provide a
  means of encapsulating extended commands in proper TPM data packets, as well
  as extracting extended command responses.

  Attributes:
    _handle: a ftdi_spi_tpm object, a USB/FTDI/SPI driver which allows
      communicate with a TPM connected over USB dongle.
  """

  HEADER_FMT = '>H2IH'
  STARTUP_CMD = '80 01 00 00 00 0c 00 00 01 44 00 00'
  STARTUP_RSP = ('80 01 00 00 00 0a 00 00 00 00',
                 '80 01 00 00 00 0a 00 00 01 00')

  def __init__(self, freq=800*1000, debug_mode=False):
    self._handle = ftdi_spi_tpm
    if not self._handle.FtdiSpiInit(freq, debug_mode):
      raise TpmError()
    response = self.command(''.join('%c' % int('0x%s' % x, 16)
                                    for x in self.STARTUP_CMD.split()))
    if ' '.join('%2.2x' % ord(x) for x in response) not in self.STARTUP_RSP:
      raise TpmError('init failed')

  def validate(self, data_blob, response_mode=False):
    """Check if a data blob complies with TPM command/response header format."""
    (tag, size, cmd_code, _) = struct.unpack_from(
        self.HEADER_FMT, data_blob + '  ')
    prefix = 'Misformatted blob: '
    if tag not in (0x8001, 0x8002):
      raise TpmError(prefix + 'bad tag value 0x%4.4x' % tag)
    if size != len(data_blob):
      raise TpmError(prefix + 'size mismatch: header %d, actual %d' %
                     (size, len(data_blob)))
    if size > 4096:
      raise TpmError(prefix + 'invalid size %d' % size)
    if response_mode:
      return
    if cmd_code >= 0x11f and cmd_code <= 0x18f:
      return  # This is a valid command
    if cmd_code == EXT_CMD:
      return  # This is an extension command

    raise TpmError(prefix + 'invalid command code 0x%x' % cmd_code)

  def command(self, cmd_data):
    # Verify command header
    self.validate(cmd_data)
    response = self._handle.FtdiSendCommandAndWait(cmd_data)
    self.validate(response, response_mode=True)
    return response

  def wrap_ext_command(self, cmd_code, subcmd_code, cmd_body):
    return struct.pack(self.HEADER_FMT, 0x8001,
                       len(cmd_body) + struct.calcsize(self.HEADER_FMT),
                       cmd_code, subcmd_code) + cmd_body

  def unwrap_ext_response(self, expected_cmd, expected_subcmd, response):
    """Verify basic validity and strip off TPM extended command header.

    Get the response generated by the device, as it came off the wire, verify
    that header fields match expectations, then strip off the extension
    command header and return the payload to the caller.

    Args:
      expected_cmd: an int, up to 32 bits, expected value in the
        command/response field of the header. expected_subcmd, response
      expected_subcmd: an int, up to 16 bits in size, the extension command
        this response is supposed to be for.
      response: a binary string, the actual response received over the wire.
    Returns:
      the binary string of the response payload, if validation succeeded.
    Raises:
      TpmError: in case there are any validation problems, the error message
        describes the problem.
    """
    header_size = struct.calcsize(self.HEADER_FMT)
    tag, size, cmd, subcmd = struct.unpack(self.HEADER_FMT,
                                           response[:header_size])
    if tag != 0x8001:
      raise TpmError('Wrong response tag: %4.4x' % tag)
    if cmd != expected_cmd:
      raise TpmError('Unexpected response command field: %8.8x' % cmd)
    if subcmd != expected_subcmd:
      raise TpmError('Unexpected response subcommand field: %2.2x' %
                     subcmd)
    if size != len(response):
      raise TpmError('Size mismatch: header %d, actual %d' % (
          size, len(response)))
    return response[header_size:]


def hex_dump(binstr):
  """Convert string into its hex representation."""
  dump_lines = ['',]
  i = 0
  while i < len(binstr):
    strsize = min(16, len(binstr) - i)
    hexstr = ' '.join('%2.2x' % ord(x) for x in binstr[i:i+strsize])
    dump_lines.append(hexstr)
    i += strsize
  dump_lines.append('')
  return '\n'.join(dump_lines)


def get_attribute(tdesc, attr_name, required=True):
  """Retrieve an attribute value from an XML node.

  Args:

    tdesc: an Element of the ElementTree, a test descriptor containing
      necessary information to run a single encryption/description
      session.
    attr_name: a string, the name of the attribute to retrieve.
    required: a Boolean, if True - the attribute must be present in the
      descriptor, otherwise it is considered optional
  Returns:
    The attribute value as a string (ascii or binary)
  Raises:
    TpmError: on various format errors, or in case a required attribute is not
      found, the error message describes the problem.

  """
  # Fields stored in hex format by default.
  default_hex = ('cipher_text', 'iv', 'key')

  data = tdesc.find(attr_name)
  if data is None:
    if required:
      raise TpmError('node "%s" does not have attribute "%s"' %
                     (tdesc.get('name'), attr_name))
    return ''

  # Attribute is present, does it have to be decoded from hex?
  cell_format = data.get('format')
  if not cell_format:
    if attr_name in default_hex:
      cell_format = 'hex'
    else:
      cell_format = 'ascii'
  elif cell_format not in ('hex', 'ascii'):
    raise TpmError('%s:%s, unrecognizable format "%s"' %
                   (tdesc.get('name'), attr_name, cell_format))

  text = ' '.join(x.strip() for x in data.text.splitlines() if x)
  if cell_format == 'ascii':
    return text

  # Drop spaces from hex representation.
  text = text.replace(' ', '')
  if len(text) & 3:
    raise TpmError('%s:%s %swrong hex number size' %
                   (tdesc.get('name'), attr_name, hex_dump(text)))
  # Convert text to binary
  value = ''
  for x in range(len(text)/8):
    try:
      value += struct.pack('<I', int('0x%s' % text[8*x:8*(x+1)], 16))
    except ValueError:
      raise TpmError('%s:%s %swrong hex value' %
                     (tdesc.get('name'), attr_name, hex_dump(text)))
  return value


class CryptoD(object):
  """A helper object to contain an encryption scheme description.

  Attributes:
    subcmd: a 16 bit max integer, the extension subcommand to be used with
      this encryption scheme.
    sumbodes: an optional dictionary, the keys are strings, names of the
      encryption scheme submodes, the values are integers to be included in
      the appropriate subcommand fields to communicat the submode to the
      device.
  """

  def __init__(self, subcommand, submodes=None):
    self.subcmd = subcommand
    if not submodes:
      submodes = {}
    self.submodes = submodes

SUPPORTED_MODES = {
    'AES': CryptoD(AES, {
        'ECB': 0,
        'CTR': 1,
        'CBC': 2,
        'GCM': 3
    }),
}


def crypto_run(node_name, op_type, key, iv, in_text, out_text, tpm, debug_mode):
  """Perform a basic operation(encrypt or decrypt).

  This function creates an extended command with the requested parameters,
  sends it to the device, and then compares the response to the expected
  value.

  Args:
    node_name: a string, the name of the XML node this data comes from. The
      format of the name is "<enc type>:<submode> ....", where <enc type> is
      the major encryption mode (say AED or DES) and submode - a variant of
      the major scheme, if exists.

   op_type: an int, encodes the operation to perform (encrypt/decrypt), passed
     directly to the device as a field in the extended command
   key: a binary string
   iv: a binary string, might be empty
   in_text: a binary string, the input of the encrypt/decrypt operation
   out_text: a binary string, might be empty, the expected output of the
     operation. Note that it could be shorter than actual output (padded to
     integer number of blocks), in which case only its length of bytes is
     compared debug_mode: a Boolean, if True - enables tracing on the console
   tpm: a TPM object to send extended commands to an initialized TPM
   debug_mode: a Boolean, if True - this function and the FTDI driver
     generate debug messated on the console.

  Returns:
    The actual binary string, result of the operation, if the
    comparison with the expected value was successful.

  Raises:
    TpmError: in case there were problems parsing the node name, or verifying
      the operation results.
  """
  mode_name, submode_name = node_name.split(':')
  submode_name = submode_name[:3].upper()

  mode = SUPPORTED_MODES.get(mode_name.upper())
  if not mode:
    raise TpmError('unrecognizable mode in node "%s"' % node_name)

  submode = mode.submodes.get(submode_name, 0)
  cmd = '%c' % op_type    # Encrypt or decrypt
  cmd += '%c' % submode   # A particular type of a generic algorithm.
  cmd += '%c' % len(key)
  cmd += key
  cmd += '%c' % len(iv)
  if iv:
    cmd += iv
  cmd += struct.pack('>H', len(in_text))
  cmd += in_text
  if debug_mode:
    print('%d:%d cmd size' % (op_type, mode.subcmd), len(cmd), hex_dump(cmd))
  wrapped_response = tpm.command(tpm.wrap_ext_command(
      EXT_CMD, mode.subcmd, cmd))
  real_out_text = tpm.unwrap_ext_response(
      EXT_CMD, mode.subcmd, wrapped_response)
  if out_text:
    if len(real_out_text) > len(out_text):
      real_out_text = real_out_text[:len(out_text)]  # Ignore padding
    if real_out_text != out_text:
      if debug_mode:
        print('Out text mismatch in node %s:\n' % node_name)
      else:
        raise TpmError('Out text mismatch in node %s, operation %d:\n'
                       'In text:%sExpected out text:%sReal out text:%s' % (
                           node_name, op_type,
                           hex_dump(in_text),
                           hex_dump(out_text),
                           hex_dump(real_out_text)))
  return real_out_text


def crypto_test(tdesc, tpm, debug_mode):
  """Perform a single test described in the xml file.

  The xml node contains all pertinent information about the test inputs and
  outputs.

  Args:
    tdesc: an Element of the ElementTree, a test descriptor containing
      necessary information to run a single encryption/description
      session.
    tpm: a TPM object to send extended commands to an initialized TPM
    debug_mode: a Boolean, if True - this function and the FTDI driver
      generate debug messated on the console.
  Raises:
    TpmError: on various execution errors, the details are included in the
      error message.
  """
  node_name = tdesc.get('name')
  key = get_attribute(tdesc, 'key')
  if len(key) not in (16, 24, 32):
    raise TpmError('wrong key size "%s:%s"' % (
        node_name,
        ''.join('%2.2x' % ord(x) for x in key)))
  iv = get_attribute(tdesc, 'iv', required=False)
  if iv and len(iv) != 16:
    raise TpmError('wrong iv size "%s:%s"' % (
        node_name,
        ''.join('%2.2x' % ord(x) for x in iv)))
  clear_text = get_attribute(tdesc, 'clear_text')
  if debug_mode:
    print('clear text size', len(clear_text))
  cipher_text = get_attribute(tdesc, 'cipher_text', required=False)
  real_cipher_text = crypto_run(node_name, ENCRYPT, key, iv,
                                clear_text, cipher_text, tpm, debug_mode)
  crypto_run(node_name, DECRYPT, key, iv, real_cipher_text,
             clear_text, tpm, debug_mode)
  print(cursor_back + 'SUCCESS: %s' % node_name)


if __name__ == '__main__':
  tree = ET.parse(os.path.join(root_dir, 'crypto_test.xml'))
  root = tree.getroot()
  try:
    debug_needed = len(sys.argv) == 2 and sys.argv[1] == '-d'
    t = TPM(debug_mode=debug_needed)

    for child in root:
      crypto_test(child, t, debug_needed)
  except TpmError as e:
    print()
    print(e)
    if debug_needed:
      traceback.print_exc()
    sys.exit(1)
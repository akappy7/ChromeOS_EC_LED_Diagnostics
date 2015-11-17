#!/usr/bin/python2
# Copyright 2015 The Chromium OS Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""EC-3PO Interactive Console Interface

console provides the console interface between the user and the interpreter.  It
handles the presentation of the EC console including editing methods as well as
session-persistent command history.
"""
from __future__ import print_function
import argparse
from chromite.lib import cros_logging as logging
import multiprocessing
import os
import pty
import select
import sys

import interpreter


PROMPT = '> '
CONSOLE_INPUT_LINE_SIZE = 80  # Taken from the CONFIG_* with the same name.
CONSOLE_MAX_READ = 100  # Max bytes to read at a time from the user.


class EscState(object):
  """Class which contains an enumeration for states of ESC sequences."""
  ESC_START = 1
  ESC_BRACKET = 2
  ESC_BRACKET_1 = 3
  ESC_BRACKET_3 = 4
  ESC_BRACKET_8 = 5


class ControlKey(object):
  """Class which contains codes for various control keys."""
  BACKSPACE = 0x08
  CTRL_A = 0x01
  CTRL_B = 0x02
  CTRL_D = 0x04
  CTRL_E = 0x05
  CTRL_F = 0x06
  CTRL_K = 0x0b
  CTRL_N = 0xe
  CTRL_P = 0x10
  CARRIAGE_RETURN = 0x0d
  ESC = 0x1b


class MoveCursorError(Exception):
  """Exception class for errors when moving the cursor."""
  pass


class Console(object):
  """Class which provides the console interface between the EC and the user.

  This class essentially represents the console interface between the user and
  the EC.  It handles all of the console editing behaviour

  Attributes:
    master_pty: File descriptor to the master side of the PTY.  Used for driving
      output to the user and receiving user input.
    user_pty: A string representing the PTY name of the served console.
    cmd_pipe: A multiprocessing.Connection object which represents the console
      side of the command pipe.  This must be a bidirectional pipe.  Console
      commands and responses utilize this pipe.
    dbg_pipe: A multiprocessing.Connection object which represents the console's
      read-only side of the debug pipe.  This must be a unidirectional pipe
      attached to the intepreter.  EC debug messages use this pipe.
    input_buffer: A string representing the current input command.
    input_buffer_pos: An integer representing the current position in the buffer
      to insert a char.
    partial_cmd: A string representing the command entered on a line before
      pressing the up arrow keys.
    esc_state: An integer represeting the current state within an escape
      sequence.
    line_limit: An integer representing the maximum number of characters on a
      line.
    history: A list of strings containing the past entered console commands.
    history_pos: An integer representing the current history buffer position.
      This index is used to show previous commands.
    prompt: A string representing the console prompt displayed to the user.
  """

  def __init__(self, master_pty, user_pty, cmd_pipe, dbg_pipe):
    """Initalises a Console object with the provided arguments.

    Args:
    master_pty: File descriptor to the master side of the PTY.  Used for driving
      output to the user and receiving user input.
    user_pty: A string representing the PTY name of the served console.
    cmd_pipe: A multiprocessing.Connection object which represents the console
      side of the command pipe.  This must be a bidirectional pipe.  Console
      commands and responses utilize this pipe.
    dbg_pipe: A multiprocessing.Connection object which represents the console's
      read-only side of the debug pipe.  This must be a unidirectional pipe
      attached to the intepreter.  EC debug messages use this pipe.
    """
    self.master_pty = master_pty
    self.user_pty = user_pty
    self.cmd_pipe = cmd_pipe
    self.dbg_pipe = dbg_pipe
    self.input_buffer = ''
    self.input_buffer_pos = 0
    self.partial_cmd = ''
    self.esc_state = 0
    self.line_limit = CONSOLE_INPUT_LINE_SIZE
    self.history = []
    self.history_pos = 0
    self.prompt = PROMPT

  def __str__(self):
    """Show internal state of Console object as a string."""
    string = []
    string.append('master_pty: %s' % self.master_pty)
    string.append('user_pty: %s' % self.user_pty)
    string.append('cmd_pipe: %s' % self.cmd_pipe)
    string.append('dbg_pipe: %s' % self.dbg_pipe)
    string.append('input_buffer: %s' % self.input_buffer)
    string.append('input_buffer_pos: %d' % self.input_buffer_pos)
    string.append('esc_state: %d' % self.esc_state)
    string.append('line_limit: %d' % self.line_limit)
    string.append('history: [\'' + '\', \''.join(self.history) + '\']')
    string.append('history_pos: %d' % self.history_pos)
    string.append('prompt: \'%s\'' % self.prompt)
    string.append('partial_cmd: \'%s\''% self.partial_cmd)
    return '\n'.join(string)

  def PrintHistory(self):
    """Print the history of entered commands."""
    fd = self.master_pty
    # Make it pretty by figuring out how wide to pad the numbers.
    wide = (len(self.history) / 10) + 1
    for i in range(len(self.history)):
      line = ' %*d %s\r\n' % (wide, i, self.history[i])
      os.write(fd, line)

  def ShowPreviousCommand(self):
    """Shows the previous command from the history list."""
    # There's nothing to do if there's no history at all.
    if not self.history:
      logging.debug('No history to print.')
      return

    # Don't do anything if there's no more history to show.
    if self.history_pos == 0:
      logging.debug('No more history to show.')
      return

    logging.debug('current history position: %d.', self.history_pos)

    # Decrement the history buffer position.
    self.history_pos -= 1
    logging.debug('new history position.: %d', self.history_pos)

    # Save the text entered on the console if any.
    if self.history_pos == len(self.history)-1:
      logging.debug('saving partial_cmd: \'%s\'', self.input_buffer)
      self.partial_cmd = self.input_buffer

    # Backspace the line.
    for _ in range(self.input_buffer_pos):
      self.SendBackspace()

    # Print the last entry in the history buffer.
    logging.debug('printing previous entry %d - %s', self.history_pos,
                  self.history[self.history_pos])
    fd = self.master_pty
    prev_cmd = self.history[self.history_pos]
    os.write(fd, prev_cmd)
    # Update the input buffer.
    self.input_buffer = prev_cmd
    self.input_buffer_pos = len(prev_cmd)

  def ShowNextCommand(self):
    """Shows the next command from the history list."""
    # Don't do anything if there's no history at all.
    if not self.history:
      logging.debug('History buffer is empty.')
      return

    fd = self.master_pty

    logging.debug('current history position: %d', self.history_pos)
    # Increment the history position.
    self.history_pos += 1

    # Restore the partial cmd.
    if self.history_pos == len(self.history):
      logging.debug('Restoring partial command of \'%s\'', self.partial_cmd)
      # Backspace the line.
      for _ in range(self.input_buffer_pos):
        self.SendBackspace()
      # Print the partially entered command if any.
      os.write(fd, self.partial_cmd)
      self.input_buffer = self.partial_cmd
      self.input_buffer_pos = len(self.input_buffer)
      # Now that we've printed it, clear the partial cmd storage.
      self.partial_cmd = ''
      # Reset history position.
      self.history_pos = len(self.history)
      return

    logging.debug('new history position: %d', self.history_pos)
    if self.history_pos > len(self.history)-1:
      logging.debug('No more history to show.')
      self.history_pos -= 1
      logging.debug('Reset history position to %d', self.history_pos)
      return

    # Backspace the line.
    for _ in range(self.input_buffer_pos):
      self.SendBackspace()

    # Print the newer entry from the history buffer.
    logging.debug('printing next entry %d - %s', self.history_pos,
                  self.history[self.history_pos])
    next_cmd = self.history[self.history_pos]
    os.write(fd, next_cmd)
    # Update the input buffer.
    self.input_buffer = next_cmd
    self.input_buffer_pos = len(next_cmd)
    logging.debug('new history position: %d.', self.history_pos)

  def SliceOutChar(self):
    """Remove a char from the line and shift everything over 1 column."""
    fd = self.master_pty
    # Remove the character at the input_buffer_pos by slicing it out.
    self.input_buffer = self.input_buffer[0:self.input_buffer_pos] + \
                        self.input_buffer[self.input_buffer_pos+1:]
    # Write the rest of the line
    moved_col = os.write(fd, self.input_buffer[self.input_buffer_pos:])
    # Write a space to clear out the last char
    moved_col += os.write(fd, ' ')
    # Update the input buffer position.
    self.input_buffer_pos += moved_col
    # Reset the cursor
    self.MoveCursor('left', moved_col)

  def HandleEsc(self, byte):
    """HandleEsc processes escape sequences.

    Args:
      byte: An integer representing the current byte in the sequence.
    """
    # We shouldn't be handling an escape sequence if we haven't seen one.
    assert self.esc_state != 0

    if self.esc_state is EscState.ESC_START:
      logging.debug('ESC_START')
      if byte == ord('['):
        self.esc_state = EscState.ESC_BRACKET
        return

      else:
        logging.error('Unexpected sequence. %c' % byte)
        self.esc_state = 0

    elif self.esc_state is EscState.ESC_BRACKET:
      logging.debug('ESC_BRACKET')
      # Left Arrow key was pressed.
      if byte == ord('D'):
        logging.debug('Left arrow key pressed.')
        self.MoveCursor('left', 1)
        self.esc_state = 0 # Reset the state.
        return

      # Right Arrow key.
      elif byte == ord('C'):
        logging.debug('Right arrow key pressed.')
        self.MoveCursor('right', 1)
        self.esc_state = 0 # Reset the state.
        return

      # Up Arrow key.
      elif byte == ord('A'):
        logging.debug('Up arrow key pressed.')
        self.ShowPreviousCommand()
        # Reset the state.
        self.esc_state = 0 # Reset the state.
        return

      # Down Arrow key.
      elif byte == ord('B'):
        logging.debug('Down arrow key pressed.')
        self.ShowNextCommand()
        # Reset the state.
        self.esc_state = 0 # Reset the state.
        return

      # For some reason, minicom sends a 1 instead of 7. /shrug
      # TODO(aaboagye): Figure out why this happens.
      elif byte == ord('1') or byte == ord('7'):
        self.esc_state = EscState.ESC_BRACKET_1

      elif byte == ord('3'):
        self.esc_state = EscState.ESC_BRACKET_3

      elif byte == ord('8'):
        self.esc_state = EscState.ESC_BRACKET_8

      else:
        logging.error(r'Bad or unhandled escape sequence. got ^[%c\(%d)'
                      % (chr(byte), byte))
        self.esc_state = 0
        return

    elif self.esc_state is EscState.ESC_BRACKET_1:
      logging.debug('ESC_BRACKET_1')
      # HOME key.
      if byte == ord('~'):
        logging.debug('Home key pressed.')
        self.MoveCursor('left', self.input_buffer_pos)
        self.esc_state = 0 # Reset the state.
        logging.debug('ESC sequence complete.')
        return

    elif self.esc_state is EscState.ESC_BRACKET_3:
      logging.debug('ESC_BRACKET_3')
      # DEL key.
      if byte == ord('~'):
        logging.debug('Delete key pressed.')
        if self.input_buffer_pos != len(self.input_buffer):
          self.SliceOutChar()
        self.esc_state = 0 # Reset the state.

    elif self.esc_state is EscState.ESC_BRACKET_8:
      logging.debug('ESC_BRACKET_8')
      # END key.
      if byte == ord('~'):
        logging.debug('End key pressed.')
        self.MoveCursor('right',
                        len(self.input_buffer) - self.input_buffer_pos)
        self.esc_state = 0 # Reset the state.
        logging.debug('ESC sequence complete.')
        return

      else:
        logging.error('Unexpected sequence. %c' % byte)
        self.esc_state = 0

    else:
      logging.error('Unexpected sequence. %c' % byte)
      self.esc_state = 0

  def ProcessInput(self):
    """Captures the input determines what actions to take."""
    # There's nothing to do if the input buffer is empty.
    if len(self.input_buffer) == 0:
      return

    # Don't store 2 consecutive identical commands in the history.
    if (self.history and self.history[-1] != self.input_buffer
        or not self.history):
      self.history.append(self.input_buffer)

    # Split the command up by spaces.
    line = self.input_buffer.split(' ')
    logging.debug('cmd: %s' % (self.input_buffer))
    cmd = line[0].lower()

    # The 'history' command is a special case that we handle locally.
    if cmd == 'history':
      self.PrintHistory()
      return

    # Send the command to the interpreter.
    logging.debug('Sending command to interpreter.')
    self.cmd_pipe.send(self.input_buffer)

  def HandleChar(self, byte):
    """HandleChar does a certain action when it receives a character.

    Args:
      byte: An integer representing the character received from the user.
    """
    # Keep handling the ESC sequence if we're in the middle of it.
    if self.esc_state != 0:
      self.HandleEsc(byte)
      return

    # When we're at the end of the line, we should only allow going backwards,
    # backspace, carriage return, up, or down.  The arrow keys are escape
    # sequences, so we let the escape...escape.
    if (self.input_buffer_pos >= self.line_limit and
        byte not in [ControlKey.CTRL_B, ControlKey.ESC, ControlKey.BACKSPACE,
                     ControlKey.CTRL_A, ControlKey.CARRIAGE_RETURN,
                     ControlKey.CTRL_P, ControlKey.CTRL_N]):
      return

    # If the input buffer is full we can't accept new chars.
    buffer_full = len(self.input_buffer) >= self.line_limit

    fd = self.master_pty

    # Carriage_Return/Enter
    if byte == ControlKey.CARRIAGE_RETURN:
      logging.debug('Enter key pressed.')
      # Put a carriage return/newline and the print the prompt.
      os.write(fd, '\r\n')

      # TODO(aaboagye): When we control the printing of all output, print the
      # prompt AFTER printing all the output.  We can't do it yet because we
      # don't know how much is coming from the EC.

      # Print the prompt.
      os.write(fd, self.prompt)
      # Process the input.
      self.ProcessInput()
      # Now, clear the buffer.
      self.input_buffer = ''
      self.input_buffer_pos = 0
      # Reset history buffer pos.
      self.history_pos = len(self.history)
      # Clear partial command.
      self.partial_cmd = ''

    # Backspace
    elif byte == ControlKey.BACKSPACE:
      logging.debug('Backspace pressed.')
      if self.input_buffer_pos > 0:
        # Move left 1 column.
        self.MoveCursor('left', 1)
        # Remove the character at the input_buffer_pos by slicing it out.
        self.SliceOutChar()

      logging.debug('input_buffer_pos: %d' % (self.input_buffer_pos))

    # Ctrl+A. Move cursor to beginning of the line
    elif byte == ControlKey.CTRL_A:
      logging.debug('Control+A pressed.')
      self.MoveCursor('left', self.input_buffer_pos)

    # Ctrl+B. Move cursor left 1 column.
    elif byte == ControlKey.CTRL_B:
      logging.debug('Control+B pressed.')
      self.MoveCursor('left', 1)

    # Ctrl+D. Delete a character.
    elif byte == ControlKey.CTRL_D:
      logging.debug('Control+D pressed.')
      if self.input_buffer_pos != len(self.input_buffer):
        # Remove the character by slicing it out.
        self.SliceOutChar()

    # Ctrl+E. Move cursor to end of the line.
    elif byte == ControlKey.CTRL_E:
      logging.debug('Control+E pressed.')
      self.MoveCursor('right',
                      len(self.input_buffer) - self.input_buffer_pos)

    # Ctrl+F. Move cursor right 1 column.
    elif byte == ControlKey.CTRL_F:
      logging.debug('Control+F pressed.')
      self.MoveCursor('right', 1)

    # Ctrl+K. Kill line.
    elif byte == ControlKey.CTRL_K:
      logging.debug('Control+K pressed.')
      self.KillLine()

    # Ctrl+N. Next line.
    elif byte == ControlKey.CTRL_N:
      logging.debug('Control+N pressed.')
      self.ShowNextCommand()

    # Ctrl+P. Previous line.
    elif byte == ControlKey.CTRL_P:
      logging.debug('Control+P pressed.')
      self.ShowPreviousCommand()

    # ESC sequence
    elif byte == ControlKey.ESC:
      # Starting an ESC sequence
      self.esc_state = EscState.ESC_START

    # Only print printable chars.
    elif IsPrintable(byte):
      # Drop the character if we're full.
      if buffer_full:
        logging.debug('Dropped char: %c(%d)', byte, byte)
        return
      # Print the character.
      os.write(fd, chr(byte))
      # Print the rest of the line (if any).
      extra_bytes_written = os.write(fd,
                                     self.input_buffer[self.input_buffer_pos:])

      # Recreate the input buffer.
      self.input_buffer = (self.input_buffer[0:self.input_buffer_pos] +
                           ('%c' % byte) +
                           self.input_buffer[self.input_buffer_pos:])
      # Update the input buffer position.
      self.input_buffer_pos += 1 + extra_bytes_written

      # Reset the cursor if we wrote any extra bytes.
      if extra_bytes_written:
        self.MoveCursor('left', extra_bytes_written)

      logging.debug('input_buffer_pos: %d' % (self.input_buffer_pos))

  def MoveCursor(self, direction, count):
    """MoveCursor moves the cursor left or right by count columns.

    Args:
      direction: A string that should be either 'left' or 'right' representing
        the direction to move the cursor on the console.
      count: An integer representing how many columns the cursor should be
        moved.

    Raises:
      ValueError: If the direction is not equal to 'left' or 'right'.
    """
    # If there's nothing to move, we're done.
    if not count:
      return
    fd = self.master_pty
    seq = '\033[' + str(count)
    if direction == 'left':
      # Bind the movement.
      if count > self.input_buffer_pos:
        count = self.input_buffer_pos
      seq += 'D'
      logging.debug('move cursor left %d', count)
      self.input_buffer_pos -= count

    elif direction == 'right':
      # Bind the movement.
      if (count + self.input_buffer_pos) > len(self.input_buffer):
        count = 0
      seq += 'C'
      logging.debug('move cursor right %d', count)
      self.input_buffer_pos += count

    else:
      raise MoveCursorError(('The only valid directions are \'left\' and '
                             '\'right\''))

    logging.debug('input_buffer_pos: %d' % self.input_buffer_pos)
    # Move the cursor.
    if count != 0:
      os.write(fd, seq)

  def KillLine(self):
    """Kill the rest of the line based on the input buffer position."""
    # Killing the line is killing all the text to the right.
    diff = len(self.input_buffer) - self.input_buffer_pos
    logging.debug('diff: %d' % diff)
    # Diff shouldn't be negative, but if it is for some reason, let's try to
    # correct the cursor.
    if diff < 0:
      logging.warning('Resetting input buffer position to %d...',
                      len(self.input_buffer))
      self.MoveCursor('left', -diff)
      return
    if diff:
      self.MoveCursor('right', diff)
      for _ in range(diff):
        self.SendBackspace()
      self.input_buffer_pos -= diff
      self.input_buffer = self.input_buffer[0:self.input_buffer_pos]

  def SendBackspace(self):
    """Backspace a character on the console."""
    os.write(self.master_pty, '\033[1D \033[1D')


def IsPrintable(byte):
  """Determines if a byte is printable.

  Args:
    byte: An integer potentially representing a printable character.

  Returns:
    A boolean indicating whether the byte is a printable character.
  """
  return byte >= ord(' ') and byte <= ord('~')


def StartLoop(console):
  """Starts the infinite loop of console processing.

  Args:
    console: A Console object that has been properly initialzed.
  """
  logging.info('EC Console is being served on %s.', console.user_pty)
  logging.debug(console)
  while True:
    # Check to see if pipes or the console are ready for reading.
    read_list = [console.master_pty, console.cmd_pipe, console.dbg_pipe]
    ready_for_reading = select.select(read_list, [], [])[0]

    for obj in ready_for_reading:
      if obj is console.master_pty:
        logging.debug('Input from user')
        # Convert to bytes so we can look for non-printable chars such as
        # Ctrl+A, Ctrl+E, etc.
        line = bytearray(os.read(console.master_pty, CONSOLE_MAX_READ))
        for i in line:
          # Handle each character as it arrives.
          console.HandleChar(i)

      elif obj is console.cmd_pipe:
        data = console.cmd_pipe.recv()
        # Write it to the user console.
        logging.debug('|CMD|->\'%s\'', data)
        os.write(console.master_pty, data)

      elif obj is console.dbg_pipe:
        data = console.dbg_pipe.recv()
        # Write it to the user console.
        logging.debug('|DBG|->\'%s\'', data)
        os.write(console.master_pty, data)


def main():
  """Kicks off the EC-3PO interactive console interface and interpreter.

  We create some pipes to communicate with an interpreter, instantiate an
  interpreter, create a PTY pair, and begin serving the console interface.
  """
  # Set up argument parser.
  parser = argparse.ArgumentParser(description=('Start interactive EC console '
                                                'and interpreter.'))
  # TODO(aaboagye): Eventually get this from servod.
  parser.add_argument('ec_uart_pty',
                      help=('The full PTY name that the EC UART'
                            ' is present on. eg: /dev/pts/12'))
  parser.add_argument('--log-level',
                      default='info',
                      help=('info, debug, warning, error, or critical'))

  # Parse arguments.
  args = parser.parse_args()

  # Can't do much without an EC to talk to.
  if not args.ec_uart_pty:
    parser.print_help()
    sys.exit(1)

  # Set logging level.
  args.log_level = args.log_level.lower()
  if args.log_level == 'info':
    log_level = logging.INFO
  elif args.log_level == 'debug':
    log_level = logging.DEBUG
  elif args.log_level == 'warning':
    log_level = logging.WARNING
  elif args.log_level == 'error':
    log_level = logging.ERROR
  elif args.log_level == 'critical':
    log_level = logging.CRITICAL
  else:
    print('Error: Invalid log level.')
    parser.print_help()
    sys.exit(1)

  # Start logging with a timestamp, module, and log level shown in each log
  # entry.
  logging.basicConfig(level=log_level, format=('%(asctime)s - %(module)s -'
                                               ' %(levelname)s - %(message)s'))

  # Create some pipes to communicate between the interpreter and the console.
  # The command pipe is bidirectional.
  cmd_pipe_interactive, cmd_pipe_interp = multiprocessing.Pipe()
  # The debug pipe is unidirectional from interpreter to console only.
  dbg_pipe_interactive, dbg_pipe_interp = multiprocessing.Pipe(duplex=False)

  # Create an interpreter instance.
  itpr = interpreter.Interpreter(args.ec_uart_pty, cmd_pipe_interp,
                                 dbg_pipe_interp, log_level)

  # Spawn an interpreter process.
  itpr_process = multiprocessing.Process(target=interpreter.StartLoop,
                                         args=(itpr,))
  # Make sure to kill the interpreter when we terminate.
  itpr_process.daemon = True
  # Start the interpreter.
  itpr_process.start()

  # Open a new pseudo-terminal pair
  (master_pty, user_pty) = pty.openpty()
  # Create a console.
  console = Console(master_pty, os.ttyname(user_pty), cmd_pipe_interactive,
                    dbg_pipe_interactive)
  # Start serving the console.
  StartLoop(console)


if __name__ == '__main__':
  main()
import os
import fcntl
import termios
import signal
import time
import select
import ctypes
import posix_spawn


# Define necessary structures and constants
class posix_spawn_file_actions_t(ctypes.Structure):
    _fields_ = [("__allocated", ctypes.c_int),
                ("__used", ctypes.c_int),
                ("__actions", ctypes.c_void_p),
                ("__pad", ctypes.c_int * 16)]

class posix_spawnattr_t(ctypes.Structure):
    _fields_ = [("__flags", ctypes.c_short),
                ("__pgrp", ctypes.c_int),
                ("__sd", ctypes.c_byte * 16),
                ("__ss", ctypes.c_byte * 16)]

SHELL = b'/bin/zsh'

def read_from_pty(master_fd):
    """Read output from the master side of the PTY and print it."""
    while True:
        r, _, _ = select.select([master_fd], [], [], 0.1)
        if master_fd in r:
            try:
                output = os.read(master_fd, 1024)
                print(output.decode('utf-8', errors='replace'), end='', flush=True)
                if b'EndPrompt' in output:
                    break
                if not output:
                    print("EOF")
                    break
            except OSError:
                break

def write_to_pty(master_fd, input_str):
    """Write input to the master side of the PTY."""
    os.write(master_fd, input_str.encode('utf-8'))

def main():
    print("Running PTY with posix_spawn...")

    # Open a new pseudoterminal
    master_fd, slave_fd = os.openpty()

    # Prepare arguments for posix_spawn
    argv = (ctypes.c_char_p * 2)(SHELL, None)
    envp = (ctypes.c_char_p * 1)(None)

    # Initialize posix_spawn_file_actions_t
    file_actions = posix_spawn_file_actions_t()
    posix_spawn.posix_spawn_file_actions_init(ctypes.byref(file_actions))

    # Set up file actions to use the slave PTY
    posix_spawn.posix_spawn_file_actions_adddup2(ctypes.byref(file_actions), slave_fd, 0)
    os.posix_spawn_file_actions_adddup2(ctypes.byref(file_actions), slave_fd, 1)
    os.posix_spawn_file_actions_adddup2(ctypes.byref(file_actions), slave_fd, 2)
    os.posix_spawn_file_actions_addclose(ctypes.byref(file_actions), master_fd)

    # Initialize posix_spawnattr_t
    attr = posix_spawnattr_t()
    os.posix_spawnattr_init(ctypes.byref(attr))

    # Spawn the process
    pid = ctypes.c_int()
    result = os.posix_spawn(ctypes.byref(pid), SHELL, ctypes.byref(file_actions),
                              ctypes.byref(attr), argv, envp)

    if result != 0:
        print(f"posix_spawn failed with error {result}")
        return

    print(f"Child PID is {pid.value}")

    # Close the slave side of the PTY in the parent process
    os.close(slave_fd)

    try:
        # Set the parent process to ignore SIGCHLD to prevent zombie processes
        signal.signal(signal.SIGCHLD, signal.SIG_IGN)

        # Write some commands to the PTY
        commands = [
            "echo Hello from PTY\n",
            "ls\n",
            "pwd\n",
            "python -c 'import sys; print(sys.stdout.isatty())'\n",
            "echo $TERM\n",
            "ps -efl | grep zsh\n",
            "echo dummy\n",
            "exit\n",
        ]

        for command in commands:
            write_to_pty(master_fd, command)
            # Allow some time for the command to be executed and output to be read
            time.sleep(0.5)
            # Read the output from the PTY
            read_from_pty(master_fd)

    except KeyboardInterrupt:
        print("\nKeyboardInterrupt received, closing...")
    finally:
        os.close(master_fd)
        os.posix_spawn_file_actions_destroy(ctypes.byref(file_actions))
        os.posix_spawnattr_destroy(ctypes.byref(attr))

if __name__ == "__main__":
    print('-'*80)
    main()
    print('-'*80)
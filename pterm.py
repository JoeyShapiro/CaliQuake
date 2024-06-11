import os
import pty
import signal
import time
import select

SHELL = 'bash'

def read_from_pty(master_fd):
    """Read output from the master side of the PTY and print it."""
    while True:
        r, _, _ = select.select([master_fd], [], [], 0.1)
        if master_fd in r:
            try:
                output = os.read(master_fd, 1024)
                print(output.decode('utf-8'), end='')
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
    # Fork the current process
    pid, master_fd = pty.fork()

    if pid == 0:
        # Child process
        # Replace the child process with the bash shell
        os.execlp(SHELL, SHELL)
    else:
        # Parent process
        try:
            # Set the parent process to ignore SIGCHLD to prevent zombie processes
            signal.signal(signal.SIGCHLD, signal.SIG_IGN)

            # Write some commands to the PTY
            commands = [
                "echo Hello from PTY\n",
                "ls\n",
                "pwd\n",
                "exit\n"
            ]

            for command in commands:
                write_to_pty(master_fd, command)
                # Allow some time for the command to be executed and output to be read
                time.sleep(1)
                # Read the output from the PTY
                read_from_pty(master_fd)


        except KeyboardInterrupt:
            print("\nKeyboardInterrupt received, closing...")
        finally:
            os.close(master_fd)

if __name__ == "__main__":
    print('-'*80)
    main()
    print('-'*80)

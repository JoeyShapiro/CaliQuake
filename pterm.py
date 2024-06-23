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
                with open(f'output.{SHELL}.txt', 'ab') as f:
                    f.write(output)
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
    print("Running PTY...")
    # Fork the current process
    pid, master_fd = pty.fork()

    if pid == 0:
        # Child process
        # Replace the child process with the bash shell
        print("Child PID is", os.getpid())
        os.execlp(SHELL, SHELL)
    else:
        print("Parent PID is", os.getpid())
        # Parent process
        try:
            # Set the parent process to ignore SIGCHLD to prevent zombie processes
            signal.signal(signal.SIGCHLD, signal.SIG_IGN)

            # Write some commands to the PTY
            commands = [
                "echo Hello from PTY\n",
                "ls\n",
                "pwd\n",
                "python -c 'import sys; print(sys.stdout.isatty())'\n"
                "exit\n",
            ]

            # get the termios structure
            import termios
            attr = termios.tcgetattr(master_fd)
            print(attr)
            """
            [11010, 3, 19200, 1483, 9600, 9600, [b'\x04', b'\xff', b'\xff', b'\x7f', b'\x17', b'\x15', b'\x12', b'\xff', b'\x03', b'\x1c', b'\x1a', b'\x19', b'\x11', b'\x13', b'\x16', b'\x0f', b'\x01', b'\x00', b'\x14', b'\xff']]
            termios(c_iflag: 11010, c_oflag: 3, c_cflag: 19200, c_lflag: 1483, c_cc: (4, 255, 255, 127, 23, 21, 18, 255, 3, 28, 26, 25, 17, 19, 22, 15, 1, 0, 20, 255), c_ispeed: 9600, c_ospeed: 9600)
            """

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

# crashes rust !?
# a = [116, 104, 114, 101, 97, 100, 32, 39, 109, 97, 105, 110, 39, 32, 112, 97, 110, 105, 99, 107, 101, 100, 32, 97, 116, 32, 47, 112, 114, 105, 118, 97, 116, 101, 47, 116, 109, 112, 47, 97, 54, 55, 54, 57, 51, 55, 102, 45, 102, 98, 100, 55, 45, 52, 57, 56, 100, 45, 57, 99, 101, 53, 45, 50, 100, 57, 53, 50, 55, 97, 99, 51, 52, 99, 55, 47, 108, 105, 98, 47, 97, 108, 97, 99, 114, 105, 116, 116, 121, 95, 116, 101, 114, 109, 105, 110, 97, 108, 47, 115, 114, 99, 47, 103, 114, 105, 100, 47, 109, 111, 100, 46, 114, 115, 0]
# b = ''.join([chr(i) for i in a])
# print(b)
# exit()

if __name__ == "__main__":
    print('-'*80)
    main()
    print('-'*80)

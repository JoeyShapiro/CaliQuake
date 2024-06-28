import pty
import os

def read_output(fd):
    data = os.read(fd, 1024)
    return data

commands = [b'echo Hello from PTY\n', b'ls -lah\n', b'pwd\n', b'python -c "import sys; print(sys.stdout.isatty())"\n', b'l', b's', b' ', b'-']

pid, fd = pty.fork()
if pid == 0:  # Child process
    os.execvp('zsh', ['zsh'])
else:  # Parent process
    while True:
        try:
            data = read_output(fd)
            print(repr(data))  # Print raw output including control sequences
            if len(commands) > 0:
                os.write(fd, commands.pop(0))
                print('------------------ Command sent')
            if data == b'':
                break
        except EOFError:
            break
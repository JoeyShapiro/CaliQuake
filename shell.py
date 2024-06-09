import os
import subprocess

# get the output of the ls command
# print('starting')
# output = os.popen('zsh').read()
# print(output)
# print('done')

from subprocess import Popen, PIPE, STDOUT

# there was something about a bug, but i cant find it
# stdout would hang when read
# https://stackoverflow.com/questions/803265/getting-realtime-output-using-subprocess
# p = Popen(['zsh'], stdout=PIPE, stdin=PIPE, stderr=PIPE)
# # for line in p.stdout:
# #     print(line)
# while True:
#     p.stdin.write(b'ls\n')
#     #p.stdin.flush()
#     line = p.stderr.read()#.decode('utf-8')
#     print(line, flush=True)
#     if not line:
#         break
# for some reasion this doesnt work

# but this does, so oh well. communicate must be magix
with subprocess.Popen(
    [
        "zsh",
    ],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    shell=True,
) as process:
    print("running")
    print(process.stdin.write(b"echo $TERM\n"))
    print(process.stdin.write(b"echo $PS1\n"))
    print(process.stdin.write(b"echo $PATH\n"))
    print(process.stdin.write(b"ls\n"))
    process.stdin.flush()
    stdout, stderr = process.communicate(
        input=f"ls\n".encode("utf-8"), timeout=10
    )
    print(f"\"{stdout.decode('utf-8')}\", \"{stderr.decode('utf-8')}\"")
    print("done")

import pty, os

output_bytes = []

def read(fd):
    data = os.read(fd, 1024)
    output_bytes.append(data)
    return data

to_write = ['ls\n']

import time
# this gives it color for some reason
def write(fd):
    # data = input('ls\n')
    # print('writing') # printing it goes to new pty
    # oh, same with input
    os.write(fd, to_write.pop().encode())

pty.spawn(['zsh'], read)

print('-' * 80)
with open('output.txt', 'wb') as f:
    for output in output_bytes:
        f.write(output)
        print(output.decode('utf-8'))
print('-' * 80)

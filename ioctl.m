
#import <Foundation/Foundation.h>
#import <util.h>
#import <termios.h>
#import <sys/ioctl.h>
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Declare variables
        posix_spawn_file_actions_t fileActions;
        posix_spawnattr_t spawnAttr;
        int master, slave;
        pid_t pid;

        // Set up environment
        NSMutableDictionary *environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
        const char *path = getenv("PATH");
        if (path) {
            environment[@"PATH"] = [NSString stringWithUTF8String:path];
        }
        environment[@"TERM"] = @"xterm-256color"; // TODO: does not get set

        // Initialize file actions
        posix_spawn_file_actions_init(&fileActions);

        // Set up window size
        struct winsize winp = {0};
        winp.ws_row = 24; // TODO: Replace with actual row value
        winp.ws_col = 80; // TODO: Replace with actual column value

        // Open pseudo-terminal
        int result = openpty(&master, &slave, NULL, NULL, &winp);
        if (result != 0) {
            NSLog(@"Error creating pseudo-terminal: %d", result);
            return 1;
        }

        // Set terminal attributes
        struct termios term;
        tcgetattr(master, &term);
        // Uncomment these lines if needed
        // term.c_lflag &= ~(ECHO | ECHOCTL);
        // term.c_lflag &= ~(ICANON | ECHO);
        tcsetattr(master, TCSAFLUSH, &term);

        // Set up file actions for slave PTY
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDIN_FILENO);
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDOUT_FILENO);
        posix_spawn_file_actions_adddup2(&fileActions, slave, STDERR_FILENO);
        posix_spawn_file_actions_addclose(&fileActions, master);

        // Set up spawn attributes
        posix_spawnattr_init(&spawnAttr);
        posix_spawnattr_setflags(&spawnAttr, POSIX_SPAWN_SETSID);

        // Prepare arguments for posix_spawn
        const char *shell = "/bin/zsh";
        char *args[] = {(char *)shell, NULL};

        // Convert environment dictionary to C-style array
        NSMutableArray *envArray = [NSMutableArray array];
        for (NSString *key in environment) {
            [envArray addObject:[NSString stringWithFormat:@"%@=%@", key, environment[key]]];
        }
        char **envp = malloc(sizeof(char *) * (envArray.count + 1));
        for (NSUInteger i = 0; i < envArray.count; i++) {
            envp[i] = strdup([envArray[i] UTF8String]);
        }
        envp[envArray.count] = NULL;

        // Spawn the process
        int spawnResult = posix_spawn(&pid, shell, &fileActions, &spawnAttr, args, envp);

        // Clean up environment array
        for (NSUInteger i = 0; i < envArray.count; i++) {
            free(envp[i]);
        }
        free(envp);

        if (spawnResult != 0) {
            NSLog(@"Error launching shell: %d", spawnResult);
            return 1;
        }

        // Set controlling terminal
        if (ioctl(master, TIOCSCTTY, pid) == -1) {
            NSLog(@"ioctl error: %s", strerror(errno));
        } else {
            NSLog(@"Successfully set controlling terminal");
        }

        NSLog(@"Master FD: %d, Slave FD: %d", master, slave);
        NSLog(@"Process ID: %d", pid);
        NSLog(@"Is master a TTY: %d", isatty(master));
        NSLog(@"Is slave a TTY: %d", isatty(slave));

        // Give the child process a moment to start up
        usleep(10000);  // Sleep for 10ms

        if (tcsetpgrp(slave, pid) == -1) {
            NSLog(@"tcsetpgrp error: %s", strerror(errno));
        } else {
            NSLog(@"Successfully set controlling terminal");
        }

        pid_t current_pgrp = tcgetpgrp(master);
        if (current_pgrp == -1) {
            NSLog(@"tcgetpgrp error: %s", strerror(errno));
        } else {
            NSLog(@"Current foreground process group: %d", current_pgrp);
        }

        pid_t pgrp = getpgid(pid);
        if (pgrp == -1) {
            NSLog(@"getpgid error: %s", strerror(errno));
        } else {
            NSLog(@"Process group of spawned process: %d", pgrp);
        }

        pid_t parent_sid = getsid(0);  // 0 means current process
        pid_t child_sid = getsid(pid);
        NSLog(@"Parent session ID: %d, Child session ID: %d", parent_sid, child_sid);

        // Clean up
        posix_spawn_file_actions_destroy(&fileActions);
        posix_spawnattr_destroy(&spawnAttr);
        close(slave);
        
        // TODO: Add any additional logic or interaction with the spawned process here

        // Keep the program running to maintain the spawned process
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/syscall.h>
#include <linux/fs.h>
#include <errno.h>

#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif
#ifndef RENAME_EXCHANGE
#define RENAME_EXCHANGE (1 << 1)
#endif

int main(int argc, char **argv) {
    int exchange = 0;
    int noreplace = 0;
    int help = 0;
    char *files[2] = {NULL, NULL};
    int file_count = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--exchange") == 0) {
            exchange = 1;
        } else if (strncmp(argv[i], "--update=none-fail", 18) == 0) {
            noreplace = 1;
        } else if (strcmp(argv[i], "--no-copy") == 0 ||
                   strcmp(argv[i], "-T") == 0 ||
                   strcmp(argv[i], "--no-target-directory") == 0) {
            /* ignore options supported via renameat2 */
        } else if (strcmp(argv[i], "--help") == 0) {
            help = 1;
        } else if (strcmp(argv[i], "--") == 0) {
            /* end of options */
        } else if (argv[i][0] != '-') {
            if (file_count < 2) {
                files[file_count++] = argv[i];
            }
        }
    }

    if (help) {
        printf("Usage: mv [OPTION]... SOURCE DEST\n"
               "  --exchange    exchange source and destination\n"
               "  --no-copy     do not copy if exchange fails\n"
               "  --update=none-fail fail if destination exists\n"
               "  none-fail     fail if destination exists\n");
        return 0;
    }

    if (exchange) {
        if (file_count != 2) {
            fprintf(stderr, "mv: --exchange requires exactly two operands\n");
            return 1;
        }
        long ret = syscall(__NR_renameat2, AT_FDCWD, files[0], AT_FDCWD, files[1], RENAME_EXCHANGE);
        if (ret != 0) {
            perror("mv: renameat2");
            return 1;
        }
        return 0;
    }

    if (noreplace) {
        if (file_count != 2) {
            fprintf(stderr, "mv: --update=none-fail requires exactly two operands\n");
            return 1;
        }
        long ret = syscall(__NR_renameat2, AT_FDCWD, files[0], AT_FDCWD, files[1], RENAME_NOREPLACE);
        if (ret != 0) {
            perror("mv: renameat2");
            return 1;
        }
        return 0;
    }

    execv("/bin/mv", argv);
    execv("/usr/bin/mv", argv);
    perror("mv: execv");
    return 127;
}

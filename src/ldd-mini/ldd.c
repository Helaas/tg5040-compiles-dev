#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *default_loader = "/lib/ld-linux-aarch64.so.1";

static void print_usage(const char *prog) {
    fprintf(stderr, "Usage: %s <program> [args...]\n", prog);
    fprintf(stderr, "Environment:\n");
    fprintf(stderr, "  LDD_LOADER=PATH  Override dynamic loader (default %s)\n", default_loader);
}

int main(int argc, char **argv) {
    if (argc < 2 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
        print_usage(argv[0]);
        return argc < 2 ? 1 : 0;
    }

    const char *loader = getenv("LDD_LOADER");
    if (loader == NULL || loader[0] == '\0') {
        loader = default_loader;
    }

    setenv("LD_TRACE_LOADED_OBJECTS", "1", 1);
    setenv("LD_WARN", "1", 1);
    setenv("LD_BIND_NOW", "1", 1);

    if (access(loader, X_OK) == 0) {
        char **new_argv = calloc((size_t)argc + 1, sizeof(char *));
        if (new_argv == NULL) {
            perror("calloc");
            return 1;
        }
        new_argv[0] = (char *)loader;
        for (int i = 1; i < argc; ++i) {
            new_argv[i] = argv[i];
        }
        new_argv[argc] = NULL;
        execv(loader, new_argv);
        perror("execv");
        free(new_argv);
        return 1;
    }

    /* Fallback: try to execute the program directly with LD_TRACE_LOADED_OBJECTS. */
    execv(argv[1], &argv[1]);
    fprintf(stderr, "ldd: failed to exec %s: %s\n", argv[1], strerror(errno));
    return 1;
}

#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define IPS_MAGIC 0x31535049u /* "IPS1" little-endian */
#define IPS_VERSION 1u

typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t version;
    uint64_t epoch;
    int64_t value;
    uint32_t committed;
    uint32_t checksum;
} ips_header_t;

static uint32_t fnv1a32(const uint8_t *data, size_t len) {
    uint32_t h = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        h ^= data[i];
        h *= 16777619u;
    }
    return h;
}

static uint32_t header_checksum(ips_header_t hdr) {
    hdr.checksum = 0;
    return fnv1a32((const uint8_t *)&hdr, sizeof(hdr));
}

static int write_header(int fd, const ips_header_t *hdr) {
    ssize_t n = pwrite(fd, hdr, sizeof(*hdr), 0);
    if (n != (ssize_t)sizeof(*hdr)) {
        return -1;
    }
    if (fsync(fd) != 0) {
        return -1;
    }
    return 0;
}

static int read_header(int fd, ips_header_t *hdr) {
    ssize_t n = pread(fd, hdr, sizeof(*hdr), 0);
    if (n == 0) {
        return 1; /* empty file */
    }
    if (n != (ssize_t)sizeof(*hdr)) {
        return -1;
    }
    return 0;
}

static int header_is_valid(const ips_header_t *hdr) {
    if (hdr->magic != IPS_MAGIC) {
        return 0;
    }
    if (hdr->version != IPS_VERSION) {
        return 0;
    }
    if (hdr->committed != 1u) {
        return 0;
    }
    return hdr->checksum == header_checksum(*hdr);
}

static int init_store(int fd) {
    ips_header_t hdr;
    memset(&hdr, 0, sizeof(hdr));
    hdr.magic = IPS_MAGIC;
    hdr.version = IPS_VERSION;
    hdr.epoch = 0;
    hdr.value = 0;
    hdr.committed = 1;
    hdr.checksum = header_checksum(hdr);
    return write_header(fd, &hdr);
}

static int recover_store(int fd, ips_header_t *hdr) {
    int rc = read_header(fd, hdr);
    if (rc == 1) {
        if (init_store(fd) != 0) {
            return -1;
        }
        return read_header(fd, hdr);
    }
    if (rc != 0) {
        return -1;
    }
    if (!header_is_valid(hdr)) {
        errno = EINVAL;
        return -1;
    }
    return 0;
}

static int add_delta(int fd, int64_t delta, ips_header_t *out) {
    ips_header_t current;
    if (recover_store(fd, &current) != 0) {
        return -1;
    }

    ips_header_t staged = current;
    staged.epoch = current.epoch + 1;
    staged.value = current.value + delta;
    staged.committed = 0;
    staged.checksum = header_checksum(staged);

    if (write_header(fd, &staged) != 0) {
        return -1;
    }

    ips_header_t committed = staged;
    committed.committed = 1;
    committed.checksum = header_checksum(committed);

    if (write_header(fd, &committed) != 0) {
        return -1;
    }

    *out = committed;
    return 0;
}

static void usage(const char *argv0) {
    fprintf(stderr,
            "Usage:\n"
            "  %s <store-file> init\n"
            "  %s <store-file> recover\n"
            "  %s <store-file> show\n"
            "  %s <store-file> add <delta>\n",
            argv0, argv0, argv0, argv0);
}

int main(int argc, char **argv) {
    if (argc < 3) {
        usage(argv[0]);
        return 1;
    }

    const char *path = argv[1];
    const char *cmd = argv[2];

    int fd = open(path, O_RDWR | O_CREAT, 0644);
    if (fd < 0) {
        perror("open");
        return 1;
    }

    int rc = 0;
    if (strcmp(cmd, "init") == 0) {
        rc = init_store(fd);
        if (rc == 0) {
            printf("ips:init path=%s\n", path);
        }
    } else if (strcmp(cmd, "recover") == 0 || strcmp(cmd, "show") == 0) {
        ips_header_t hdr;
        rc = recover_store(fd, &hdr);
        if (rc == 0) {
            printf("ips:state epoch=%" PRIu64 " value=%" PRId64 " committed=%u\n",
                   hdr.epoch, hdr.value, hdr.committed);
        }
    } else if (strcmp(cmd, "add") == 0) {
        if (argc < 4) {
            usage(argv[0]);
            close(fd);
            return 1;
        }
        char *endptr = NULL;
        int64_t delta = strtoll(argv[3], &endptr, 10);
        if (endptr == NULL || *endptr != '\0') {
            fprintf(stderr, "invalid delta: %s\n", argv[3]);
            close(fd);
            return 1;
        }
        ips_header_t hdr;
        rc = add_delta(fd, delta, &hdr);
        if (rc == 0) {
            printf("ips:add delta=%" PRId64 " epoch=%" PRIu64 " value=%" PRId64 "\n",
                   delta, hdr.epoch, hdr.value);
        }
    } else {
        usage(argv[0]);
        close(fd);
        return 1;
    }

    if (rc != 0) {
        perror("ips");
        close(fd);
        return 1;
    }

    close(fd);
    return 0;
}

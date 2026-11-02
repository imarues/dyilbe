#include "IPAArchiveCheck.h"
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define MAX_CDIR_SCAN (16u * 1024u * 1024u)
static uint16_t le16(const unsigned char *p) {
    return (uint16_t)(p[0] | ((uint16_t)p[1] << 8));
}
static int matches_ipa_path(const unsigned char *s, unsigned int len) {
    if (len < 13 || memcmp(s, "Payload/", 8) != 0) return 0;
    for (unsigned int j=8; j+5 <= len; j++) {
        if (memcmp(s+j, ".app/", 5) == 0 && j > 8) return 1;
    }
    return 0;
}
int esign_is_ipa_archive(const char *path) {
    if (!path || !*path) return 0;
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return 0;
    struct stat st;
    if (fstat(fd, &st) != 0 || st.st_size < 64 || !S_ISREG(st.st_mode)) {
        close(fd); return 0;
    }
    unsigned char magic[4];
    if (pread(fd, magic, 4, 0) != 4 ||
        !(magic[0] == 'P' && magic[1] == 'K' && magic[2] == 3 && magic[3] == 4)) {
        close(fd); return 0;
    }
    size_t size = (size_t)(st.st_size < MAX_CDIR_SCAN ? st.st_size : MAX_CDIR_SCAN);
    unsigned char *buf = (unsigned char *)malloc(size);
    if (!buf) { close(fd); return 0; }
    off_t off = st.st_size - (off_t)size;
    ssize_t readCount = pread(fd, buf, size, off);
    close(fd);
    if (readCount != (ssize_t)size) { free(buf); return 0; }
    int found = 0;
    for (size_t i = 0; i + 46 <= size; ++i) {
        if (buf[i] != 'P' || buf[i+1] != 'K' || buf[i+2] != 1 || buf[i+3] != 2) continue;
        unsigned int fnlen = le16(buf + i + 28);
        if (!fnlen || i + 46 + fnlen > size) continue;
        if (matches_ipa_path(buf + i + 46, fnlen)) { found=1; break; }
    }
    free(buf);
    return found;
}

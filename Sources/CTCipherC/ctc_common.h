/*
 * CrypTool for macOS – private helpers shared by the CTCipherC wrappers.
 */
#ifndef CTC_COMMON_H
#define CTC_COMMON_H

#include <stddef.h>
#include <stdint.h>

/* Bytes -> upper-case hex string (as CT1 does with sprintf("%02.2X")). */
static inline void ctc_to_hex(const uint8_t *bytes, size_t n, char *out)
{
    static const char digits[] = "0123456789ABCDEF";
    size_t i;
    for (i = 0; i < n; i++) {
        out[2 * i]     = digits[bytes[i] >> 4];
        out[2 * i + 1] = digits[bytes[i] & 15];
    }
    out[2 * n] = 0;
}

/* Process large buffers in chunks so that the bit count passed to the
 * NIST API (an int) cannot overflow. Multiple of 16 bytes. */
#define CTC_CHUNK ((size_t)1 << 20)

#endif

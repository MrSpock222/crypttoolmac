/*
 * CrypTool for macOS – IDEA block cipher (Lai/Massey), ECB/CBC.
 * Written for the CrypTool macOS port (CT1 used the SECUDE library for IDEA).
 * The IDEA patents have expired (2012).
 */
#include <string.h>
#include "ctcipherc.h"

/* Multiplication modulo 2^16+1, where 0 represents 2^16. */
static inline uint16_t idea_mul(uint16_t a, uint16_t b)
{
    uint32_t p, lo, hi;
    if (a == 0)
        return (uint16_t)(1 - b);
    if (b == 0)
        return (uint16_t)(1 - a);
    p = (uint32_t)a * b;
    lo = p & 0xFFFF;
    hi = p >> 16;
    return (uint16_t)(lo - hi + (lo < hi ? 1 : 0));
}

/* Multiplicative inverse modulo 2^16+1 (0 and 1 are self-inverse). */
static uint16_t idea_inv(uint16_t x)
{
    int32_t t0 = 0, t1 = 1, r0 = 0x10001, r1, q, tmp;
    if (x <= 1)
        return x;
    r1 = x;
    while (r1 != 0) {
        q = r0 / r1;
        tmp = r0 - q * r1; r0 = r1; r1 = tmp;
        tmp = t0 - q * t1; t0 = t1; t1 = tmp;
    }
    if (t0 < 0)
        t0 += 0x10001;
    return (uint16_t)t0;
}

static void idea_encrypt_key(const uint8_t key[16], uint16_t ek[52])
{
    uint64_t hi = 0, lo = 0, nhi;
    int i, n = 0;
    for (i = 0; i < 8; i++) {
        hi = (hi << 8) | key[i];
        lo = (lo << 8) | key[8 + i];
    }
    for (;;) {
        for (i = 0; i < 8 && n < 52; i++, n++) {
            uint64_t w = i < 4 ? hi >> (48 - 16 * i) : lo >> (48 - 16 * (i - 4));
            ek[n] = (uint16_t)w;
        }
        if (n >= 52)
            break;
        /* rotate the 128-bit key left by 25 bits */
        nhi = (hi << 25) | (lo >> 39);
        lo = (lo << 25) | (hi >> 39);
        hi = nhi;
    }
}

static void idea_decrypt_key(const uint16_t ek[52], uint16_t dk[52])
{
    int i;
    for (i = 0; i <= 8; i++) {
        const uint16_t *src = ek + 6 * (8 - i);
        uint16_t *dst = dk + 6 * i;
        dst[0] = idea_inv(src[0]);
        if (i == 0 || i == 8) {
            dst[1] = (uint16_t)(0 - src[1]);
            dst[2] = (uint16_t)(0 - src[2]);
        } else {
            dst[1] = (uint16_t)(0 - src[2]);
            dst[2] = (uint16_t)(0 - src[1]);
        }
        dst[3] = idea_inv(src[3]);
        if (i < 8) {
            dst[4] = ek[6 * (7 - i) + 4];
            dst[5] = ek[6 * (7 - i) + 5];
        }
    }
}

static void idea_block(const uint16_t k[52], const uint8_t in[8], uint8_t out[8])
{
    uint16_t x1 = (uint16_t)(in[0] << 8 | in[1]), x2 = (uint16_t)(in[2] << 8 | in[3]);
    uint16_t x3 = (uint16_t)(in[4] << 8 | in[5]), x4 = (uint16_t)(in[6] << 8 | in[7]);
    uint16_t a, b, c, d, e, f, y2, y3;
    int r;
    for (r = 0; r < 8; r++, k += 6) {
        a = idea_mul(x1, k[0]);
        b = (uint16_t)(x2 + k[1]);
        c = (uint16_t)(x3 + k[2]);
        d = idea_mul(x4, k[3]);
        e = idea_mul((uint16_t)(a ^ c), k[4]);
        f = idea_mul((uint16_t)(e + (b ^ d)), k[5]);
        e = (uint16_t)(e + f);
        x1 = (uint16_t)(a ^ f);
        x4 = (uint16_t)(d ^ e);
        x2 = (uint16_t)(c ^ f);
        x3 = (uint16_t)(b ^ e);
    }
    x1 = idea_mul(x1, k[0]);
    y2 = (uint16_t)(x3 + k[1]);
    y3 = (uint16_t)(x2 + k[2]);
    x4 = idea_mul(x4, k[3]);
    out[0] = (uint8_t)(x1 >> 8); out[1] = (uint8_t)x1;
    out[2] = (uint8_t)(y2 >> 8); out[3] = (uint8_t)y2;
    out[4] = (uint8_t)(y3 >> 8); out[5] = (uint8_t)y3;
    out[6] = (uint8_t)(x4 >> 8); out[7] = (uint8_t)x4;
}

int ctc_idea_crypt(int decrypt, int cbc, const uint8_t key[16], const uint8_t *iv8,
                   const uint8_t *in, uint8_t *out, size_t len)
{
    uint16_t ek[52], dk[52];
    uint8_t chain[8] = { 0 }, tmp[8];
    size_t off;
    int i;

    if (len % 8)
        return CTC_ERR_LENGTH;
    idea_encrypt_key(key, ek);
    if (decrypt)
        idea_decrypt_key(ek, dk);
    if (iv8)
        memcpy(chain, iv8, 8);

    for (off = 0; off < len; off += 8) {
        if (!decrypt) {
            for (i = 0; i < 8; i++)
                tmp[i] = cbc ? (uint8_t)(in[off + i] ^ chain[i]) : in[off + i];
            idea_block(ek, tmp, out + off);
            if (cbc)
                memcpy(chain, out + off, 8);
        } else {
            idea_block(dk, in + off, tmp);
            for (i = 0; i < 8; i++)
                out[off + i] = cbc ? (uint8_t)(tmp[i] ^ chain[i]) : tmp[i];
            if (cbc)
                memcpy(chain, in + off, 8);
        }
    }
    return CTC_OK;
}

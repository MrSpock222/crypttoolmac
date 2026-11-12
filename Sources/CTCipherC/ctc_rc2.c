/*
 * CrypTool for macOS – RC2 block cipher (RFC 2268), ECB/CBC.
 * Written for the CrypTool macOS port (CT1 used the SECUDE library for RC2).
 */
#include <string.h>
#include "ctcipherc.h"

/* PITABLE from RFC 2268, section 2 */
static const uint8_t rc2_pitable[256] = {
    0xd9, 0x78, 0xf9, 0xc4, 0x19, 0xdd, 0xb5, 0xed, 0x28, 0xe9, 0xfd, 0x79, 0x4a, 0xa0, 0xd8, 0x9d,
    0xc6, 0x7e, 0x37, 0x83, 0x2b, 0x76, 0x53, 0x8e, 0x62, 0x4c, 0x64, 0x88, 0x44, 0x8b, 0xfb, 0xa2,
    0x17, 0x9a, 0x59, 0xf5, 0x87, 0xb3, 0x4f, 0x13, 0x61, 0x45, 0x6d, 0x8d, 0x09, 0x81, 0x7d, 0x32,
    0xbd, 0x8f, 0x40, 0xeb, 0x86, 0xb7, 0x7b, 0x0b, 0xf0, 0x95, 0x21, 0x22, 0x5c, 0x6b, 0x4e, 0x82,
    0x54, 0xd6, 0x65, 0x93, 0xce, 0x60, 0xb2, 0x1c, 0x73, 0x56, 0xc0, 0x14, 0xa7, 0x8c, 0xf1, 0xdc,
    0x12, 0x75, 0xca, 0x1f, 0x3b, 0xbe, 0xe4, 0xd1, 0x42, 0x3d, 0xd4, 0x30, 0xa3, 0x3c, 0xb6, 0x26,
    0x6f, 0xbf, 0x0e, 0xda, 0x46, 0x69, 0x07, 0x57, 0x27, 0xf2, 0x1d, 0x9b, 0xbc, 0x94, 0x43, 0x03,
    0xf8, 0x11, 0xc7, 0xf6, 0x90, 0xef, 0x3e, 0xe7, 0x06, 0xc3, 0xd5, 0x2f, 0xc8, 0x66, 0x1e, 0xd7,
    0x08, 0xe8, 0xea, 0xde, 0x80, 0x52, 0xee, 0xf7, 0x84, 0xaa, 0x72, 0xac, 0x35, 0x4d, 0x6a, 0x2a,
    0x96, 0x1a, 0xd2, 0x71, 0x5a, 0x15, 0x49, 0x74, 0x4b, 0x9f, 0xd0, 0x5e, 0x04, 0x18, 0xa4, 0xec,
    0xc2, 0xe0, 0x41, 0x6e, 0x0f, 0x51, 0xcb, 0xcc, 0x24, 0x91, 0xaf, 0x50, 0xa1, 0xf4, 0x70, 0x39,
    0x99, 0x7c, 0x3a, 0x85, 0x23, 0xb8, 0xb4, 0x7a, 0xfc, 0x02, 0x36, 0x5b, 0x25, 0x55, 0x97, 0x31,
    0x2d, 0x5d, 0xfa, 0x98, 0xe3, 0x8a, 0x92, 0xae, 0x05, 0xdf, 0x29, 0x10, 0x67, 0x6c, 0xba, 0xc9,
    0xd3, 0x00, 0xe6, 0xcf, 0xe1, 0x9e, 0xa8, 0x2c, 0x63, 0x16, 0x01, 0x3f, 0x58, 0xe2, 0x89, 0xa9,
    0x0d, 0x38, 0x34, 0x1b, 0xab, 0x33, 0xff, 0xb0, 0xbb, 0x48, 0x0c, 0x5f, 0xb9, 0xb1, 0xcd, 0x2e,
    0xc5, 0xf3, 0xdb, 0x47, 0xe5, 0xa5, 0x9c, 0x77, 0x0a, 0xa6, 0x20, 0x68, 0xfe, 0x7f, 0xc1, 0xad
};

static void rc2_expand(const uint8_t *key, size_t t, int t1, uint16_t K[64])
{
    uint8_t L[128];
    size_t i;
    int t8 = (t1 + 7) / 8;
    uint8_t tm = (uint8_t)(0xFF >> (8 * t8 - t1));

    memcpy(L, key, t);
    for (i = t; i < 128; i++)
        L[i] = rc2_pitable[(uint8_t)(L[i - 1] + L[i - t])];
    L[128 - t8] = rc2_pitable[L[128 - t8] & tm];
    for (i = 128 - (size_t)t8; i-- > 0; )
        L[i] = rc2_pitable[L[i + 1] ^ L[i + t8]];
    for (i = 0; i < 64; i++)
        K[i] = (uint16_t)(L[2 * i] | (L[2 * i + 1] << 8));
}

static inline uint16_t rol16(uint16_t x, int s) { return (uint16_t)((x << s) | (x >> (16 - s))); }
static inline uint16_t ror16(uint16_t x, int s) { return (uint16_t)((x >> s) | (x << (16 - s))); }

static void rc2_encrypt_block(const uint16_t K[64], const uint8_t in[8], uint8_t out[8])
{
    static const int s[4] = { 1, 2, 3, 5 };
    uint16_t R[4];
    int i, j = 0, round;
    for (i = 0; i < 4; i++)
        R[i] = (uint16_t)(in[2 * i] | (in[2 * i + 1] << 8));
    for (round = 0; round < 16; round++) {
        for (i = 0; i < 4; i++) {
            R[i] = (uint16_t)(R[i] + K[j] + (R[(i + 3) & 3] & R[(i + 2) & 3]) + ((uint16_t)~R[(i + 3) & 3] & R[(i + 1) & 3]));
            j++;
            R[i] = rol16(R[i], s[i]);
        }
        if (round == 4 || round == 10)       /* mashing after mixing rounds 5 and 11 */
            for (i = 0; i < 4; i++)
                R[i] = (uint16_t)(R[i] + K[R[(i + 3) & 3] & 63]);
    }
    for (i = 0; i < 4; i++) {
        out[2 * i] = (uint8_t)R[i];
        out[2 * i + 1] = (uint8_t)(R[i] >> 8);
    }
}

static void rc2_decrypt_block(const uint16_t K[64], const uint8_t in[8], uint8_t out[8])
{
    static const int s[4] = { 1, 2, 3, 5 };
    uint16_t R[4];
    int i, j = 63, round;
    for (i = 0; i < 4; i++)
        R[i] = (uint16_t)(in[2 * i] | (in[2 * i + 1] << 8));
    for (round = 15; round >= 0; round--) {
        for (i = 3; i >= 0; i--) {
            R[i] = ror16(R[i], s[i]);
            R[i] = (uint16_t)(R[i] - K[j] - (R[(i + 3) & 3] & R[(i + 2) & 3]) - ((uint16_t)~R[(i + 3) & 3] & R[(i + 1) & 3]));
            j--;
        }
        if (round == 5 || round == 11)       /* r-mashing before r-mixing rounds 11 and 5 */
            for (i = 3; i >= 0; i--)
                R[i] = (uint16_t)(R[i] - K[R[(i + 3) & 3] & 63]);
    }
    for (i = 0; i < 4; i++) {
        out[2 * i] = (uint8_t)R[i];
        out[2 * i + 1] = (uint8_t)(R[i] >> 8);
    }
}

int ctc_rc2_crypt(int decrypt, int cbc, const uint8_t *key, size_t keyLen, int effectiveBits,
                  const uint8_t *iv8, const uint8_t *in, uint8_t *out, size_t len)
{
    uint16_t K[64];
    uint8_t chain[8] = { 0 }, tmp[8];
    size_t off;
    int i;

    if (keyLen < 1 || keyLen > 128 || effectiveBits < 1 || effectiveBits > 1024)
        return CTC_ERR_KEY;
    if (len % 8)
        return CTC_ERR_LENGTH;
    rc2_expand(key, keyLen, effectiveBits, K);
    if (iv8)
        memcpy(chain, iv8, 8);

    for (off = 0; off < len; off += 8) {
        if (!decrypt) {
            for (i = 0; i < 8; i++)
                tmp[i] = cbc ? (uint8_t)(in[off + i] ^ chain[i]) : in[off + i];
            rc2_encrypt_block(K, tmp, out + off);
            if (cbc)
                memcpy(chain, out + off, 8);
        } else {
            rc2_decrypt_block(K, in + off, tmp);
            for (i = 0; i < 8; i++)
                out[off + i] = cbc ? (uint8_t)(tmp[i] ^ chain[i]) : tmp[i];
            if (cbc)
                memcpy(chain, in + off, 8);
        }
    }
    return CTC_OK;
}

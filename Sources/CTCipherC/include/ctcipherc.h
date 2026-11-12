/*
 * CTCipherC – C block ciphers used by CrypTool for macOS (module CTModern).
 *
 * Umbrella header (imported by Swift as module `CTCipherC`). Only the clean
 * wrapper API below is public; the original AES submission sources (MARS, RC6,
 * Serpent, Twofish) live in sub directories with private headers, so their
 * colliding macros/typedefs (BYTE, DIR_ENCRYPT, MODE_CBC …) never meet.
 *
 * All functions process whole blocks only. `in` and `out` must not overlap.
 * Return value: CTC_OK or a negative CTC_ERR_* code.
 */
#ifndef CTCIPHERC_H
#define CTCIPHERC_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CTC_OK            0
#define CTC_ERR_KEY      (-1)   /* invalid key length / key material */
#define CTC_ERR_LENGTH   (-2)   /* data length is not a multiple of the block size */
#define CTC_ERR_INTERNAL (-3)   /* error reported by the reference code */

/* ------------------------------------------------------------------------
 * AES finalists (original ANSI C submission code, as used by CrypTool 1).
 *
 * The key is given as raw bytes; like CT1 it is converted to an upper-case
 * hex string and passed to the submission's makeKey(), so the byte order
 * conventions of each submission are reproduced exactly (note: Serpent's
 * reference API reads the hex key string as one big-endian number).
 * CBC mode; iv16 = 16 bytes or NULL for the all-zero IV (CT1 default).
 * keyLen: 16, 24 or 32 bytes. len: multiple of 16.
 * ---------------------------------------------------------------------- */
int ctc_mars_cbc(int decrypt, const uint8_t *key, size_t keyLen, const uint8_t *iv16,
                 const uint8_t *in, uint8_t *out, size_t len);
int ctc_rc6_cbc(int decrypt, const uint8_t *key, size_t keyLen, const uint8_t *iv16,
                const uint8_t *in, uint8_t *out, size_t len);
int ctc_serpent_cbc(int decrypt, const uint8_t *key, size_t keyLen, const uint8_t *iv16,
                    const uint8_t *in, uint8_t *out, size_t len);
int ctc_twofish_cbc(int decrypt, const uint8_t *key, size_t keyLen, const uint8_t *iv16,
                    const uint8_t *in, uint8_t *out, size_t len);

/* ------------------------------------------------------------------------
 * IDEA (128-bit key, 64-bit block). cbc = 0: ECB, otherwise CBC with iv8
 * (8 bytes or NULL = zero IV). len: multiple of 8.
 * ---------------------------------------------------------------------- */
int ctc_idea_crypt(int decrypt, int cbc, const uint8_t key[16], const uint8_t *iv8,
                   const uint8_t *in, uint8_t *out, size_t len);

/* ------------------------------------------------------------------------
 * RC2 (RFC 2268). keyLen 1…128 bytes, effectiveBits 1…1024.
 * cbc = 0: ECB, otherwise CBC with iv8 (NULL = zero IV). len: multiple of 8.
 * ---------------------------------------------------------------------- */
int ctc_rc2_crypt(int decrypt, int cbc, const uint8_t *key, size_t keyLen, int effectiveBits,
                  const uint8_t *iv8, const uint8_t *in, uint8_t *out, size_t len);

/* ------------------------------------------------------------------------
 * DESX / DESL / DESXL (port of CT1's DESXL.cpp, M. Diett, RUB 2007).
 * CBC mode with 64-bit blocks; iv8 = 8 bytes or NULL (zero IV as CT1).
 * Key: DESL 8 bytes; DESX/DESXL 24 bytes = DES key ‖ pre-whitening key ‖
 * post-whitening key. Parity bits are ignored. len: multiple of 8.
 * ---------------------------------------------------------------------- */
typedef enum {
    CTC_VARIANT_DESX  = 0,
    CTC_VARIANT_DESL  = 1,
    CTC_VARIANT_DESXL = 2,
    CTC_VARIANT_DES   = 3   /* plain DES (no whitening), for tests */
} ctc_desxl_variant;

int ctc_desxl_cbc(ctc_desxl_variant variant, int decrypt, const uint8_t *key, size_t keyLen,
                  const uint8_t *iv8, const uint8_t *in, uint8_t *out, size_t len);

/* ------------------------------------------------------------------------
 * DES / Triple DES (EDE) with the DES of the DESXL port. keyLen: 8 (DES),
 * 16 (two-key 3DES, K1 K2 K1) or 24 (three-key 3DES). cbc = 0: ECB,
 * otherwise CBC with iv8 (NULL = zero IV). len: multiple of 8.
 * ---------------------------------------------------------------------- */
int ctc_des_crypt(int decrypt, int cbc, const uint8_t *key, size_t keyLen, const uint8_t *iv8,
                  const uint8_t *in, uint8_t *out, size_t len);

#ifdef __cplusplus
}
#endif

#endif /* CTCIPHERC_H */

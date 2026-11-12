/*
 * CrypTool for macOS – wrapper around the original Twofish AES submission code
 * (CBC mode, hex key material and IV exactly as CrypTool 1 passes them).
 */
#include <string.h>
#include "twofish.h"
#include "../ctc_common.h"
#include "ctcipherc.h"
#include <pthread.h>

static pthread_once_t ctcTwofishOnce = PTHREAD_ONCE_INIT;

int ctc_twofish_cbc(int decrypt, const uint8_t *key, size_t keyLen, const uint8_t *iv16,
              const uint8_t *in, uint8_t *out, size_t len)
{
    keyInstanceTwofish ki;
    cipherInstanceTwofish ci;
    char keyHex[2 * 32 + 1];
    char ivHex[2 * 16 + 1];
    static const uint8_t zeroIV[16] = { 0 };
    size_t done;
    int rc;

    if (keyLen != 16 && keyLen != 24 && keyLen != 32)
        return CTC_ERR_KEY;
    if (len % 16)
        return CTC_ERR_LENGTH;
    if (len == 0)
        return CTC_OK;
    pthread_once(&ctcTwofishOnce, ctc_twofish_build_tables);
    memset(&ki, 0, sizeof ki);
    memset(&ci, 0, sizeof ci);
    ctc_to_hex(key, keyLen, keyHex);
    ctc_to_hex(iv16 ? iv16 : zeroIV, 16, ivHex);

    rc = makeKeyTwofish(&ki, decrypt ? DIR_DECRYPT : DIR_ENCRYPT, (int)keyLen * 8, keyHex);
    if (rc < 0)
        return CTC_ERR_KEY;
    rc = cipherInitTwofish(&ci, MODE_CBC, ivHex);
    if (rc < 0)
        return CTC_ERR_INTERNAL;

    for (done = 0; done < len; ) {
        size_t n = len - done < CTC_CHUNK ? len - done : CTC_CHUNK;
        if (decrypt)
            rc = blockDecryptTwofish(&ci, &ki, (BYTE *)(in + done), (int)(n * 8), (BYTE *)(out + done));
        else
            rc = blockEncryptTwofish(&ci, &ki, (BYTE *)(in + done), (int)(n * 8), (BYTE *)(out + done));
        if (rc < 0)
            return CTC_ERR_INTERNAL;
        done += n;
    }
    return CTC_OK;
}

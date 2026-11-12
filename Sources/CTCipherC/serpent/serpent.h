/*  aes.h  */

/*  AES Cipher header file for ANSI C Submissions
      Lawrence E. Bassham III
      Computer Security Division
      National Institute of Standards and Technology

      April 15, 1998

    This sample is to assist implementers developing to the Cryptographic 
API Profile for AES Candidate Algorithm Submissions.  Please consult this 
document as a cross-reference.

    ANY CHANGES, WHERE APPROPRIATE, TO INFORMATION PROVIDED IN THIS FILE
MUST BE DOCUMENTED.  CHANGES ARE ONLY APPROPRIATE WHERE SPECIFIED WITH
THE STRING "CHANGE POSSIBLE".  FUNCTION CALLS AND THEIR PARAMETERS CANNOT 
BE CHANGED.  STRUCTURES CAN BE ALTERED TO ALLOW IMPLEMENTERS TO INCLUDE 
IMPLEMENTATION SPECIFIC INFORMATION.
*/

/*  Includes:
	Standard include files
*/

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#include <stdio.h>
#include <stdint.h>

/* CrypTool macOS port: 32-bit words are uint32_t (was uint32_t, 64 bit on
 * LP64), the IV is 4-byte aligned. Private header. */

/*  Defines:
	Add any additional defines you need
*/

#define     DIR_ENCRYPT     0    /*  Are we encrpyting?  */
#define     DIR_DECRYPT     1    /*  Are we decrpyting?  */
#define     MODE_ECB        1    /*  Are we ciphering in ECB mode?   */
#define     MODE_CBC        2    /*  Are we ciphering in CBC mode?   */
#define     MODE_CFB1       3    /*  Are we ciphering in 1-bit CFB mode? */
#define     TRUE            1
#define     FALSE           0

/*  Error Codes - CHANGE POSSIBLE: inclusion of additional error codes  */
#define     BAD_KEY_DIR        -1  /*  Key direction is invalid, e;g;,
					unknown value */
#define     BAD_KEY_MAT        -2  /*  Key material not of correct 
					length */
#define     BAD_KEY_INSTANCE   -3  /*  Key passed is not valid  */
#define     BAD_CIPHER_MODE    -4  /*  Params struct passed to 
					cipherInit invalid */
#define     BAD_CIPHER_STATE   -5  /*  Cipher in wrong state (e.g., not 
					initialized) */

/*  CHANGE POSSIBLE:  inclusion of algorithm specific defines  */
#define     MAX_KEY_SIZE	64  /* # of ASCII char's needed to
					represent a key */
#define     MAX_IV_SIZE		32  /* # of ASCII char's needed to
					represent an IV  */

/*  Typedefs:

	Typedef'ed data storage elements.  Add any algorithm specific 
parameters at the bottom of the structs as appropriate.
*/

typedef    unsigned char    BYTE;

/*  The structure for key information */
typedef struct {
      BYTE  direction;	/*  Key used for encrypting or decrypting? */
      int   keyLen;	/*  Length of the key  */
      char  keyMaterial[MAX_KEY_SIZE+1];  /*  Raw key data in ASCII, e.g.,
      					what the user types or KAT values)*/
      /*  The following parameters are algorithm dependent, replace or
      		add as necessary  */
      uint32_t key[8];             /* The key in binary */
      uint32_t subkeys[33][4];	/* Serpent subkeys */
      } keyInstanceSerpent;

/*  The structure for cipher information */
typedef struct {
      BYTE	mode;           /* MODE_ECB, MODE_CBC, or MODE_CFB1 */
      char  IV[MAX_IV_SIZE] __attribute__((aligned(4))); 	/* A possible Initialization Vector for 
      					ciphering */
      /*  Add any algorithm specific parameters needed here  */
      int   blockSize;    	/* Sample: Handles non-128 bit block sizes
      					(if available) */
      } cipherInstanceSerpent;


/*  Function protoypes  */
int makeKeySerpent(keyInstanceSerpent *key, BYTE direction, int keyLen,
	    char *keyMaterial);

int cipherInitSerpent(cipherInstanceSerpent *cipher, BYTE mode, char *IV);

int blockEncryptSerpent(cipherInstanceSerpent *cipher, keyInstanceSerpent *key, BYTE *input, 
		 int inputLen, BYTE *outBuffer);

int blockDecryptSerpent(cipherInstanceSerpent *cipher, keyInstanceSerpent *key, BYTE *input,
		 int inputLen, BYTE *outBuffer);

void serpent_decrypt(uint32_t [4],uint32_t [4],uint32_t [33][4]);
void serpent_encrypt(uint32_t [4], uint32_t [4],uint32_t [33][4]);
#ifdef __cplusplus
}
#endif /* __cplusplus */

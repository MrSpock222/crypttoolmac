/**************************************************************************

  Copyright [2009] [CrypTool Team]

  This file is part of CrypTool.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

**************************************************************************/

//////////////////////////////////////////////////////////////////
// C++ class for symmentric encryption/decryption with
// DESL, DESX and DESXL.
//
// Coded 2007 by Markus Diett (markus@diett-it.de)
// Communication Security Group
// at the Ruhr-University Bochum  (http://www.crypto.rub.de)
//////////////////////////////////////////////////////////////////

/*
 * CrypTool for macOS: C port of DESXL.cpp/DESXL.h. The algorithm, tables and
 * the CBC chaining are unchanged; the type punning via int pointers was
 * replaced by explicit little-endian loads/stores (identical results on x86
 * and Apple Silicon), the key is passed as bytes instead of a hex string and
 * an optional IV was added (NULL = all zero, as in CT1).
 */
#include <pthread.h>
#include <string.h>
#include "ctcipherc.h"

#define BITNUM(a,b,c) (((a[(b)/8] >> (7 - ((b)%8))) & 0x01) << (c))

#define DXL_ENCRYPT 0
#define DXL_DECRYPT 1

typedef struct {
    uint8_t roundkey[16][6];   /* DES round keys */
    uint8_t desxkey[2][8];     /* DESX whitening keys (0: before, 1: after encryption) */
} desxl_ctx;

static const uint32_t desl_sbox[8][64] = {
  {8552448u, 41943040u, 41943040u, 0u, 42074112u, 32768u, 131072u, 42106880u, 33718272u, 8552448u, 32768u, 33685504u, 33554432u, 131072u, 42106880u, 8421376u, 0u, 33718272u, 163840u, 42074112u, 33587200u, 8519680u, 8388608u, 33587200u, 8519680u, 41975808u, 41975808u, 8388608u, 8421376u, 33554432u, 33685504u, 163840u, 8388608u, 33587200u, 33587200u, 8519680u, 131072u, 42106880u, 8552448u, 41943040u, 32768u, 33685504u, 42074112u, 32768u, 41975808u, 8388608u, 0u, 33718272u, 163840u, 42074112u, 8421376u, 33554432u, 42106880u, 8421376u, 33554432u, 131072u, 41943040u, 0u, 33718272u, 8552448u, 33685504u, 163840u, 8519680u, 41975808u},
  {268437568u, 272629760u, 272629760u, 0u, 272629824u, 2048u, 64u, 272631872u, 4196416u, 268437568u, 2048u, 4194368u, 4194304u, 64u, 272631872u, 268437504u, 0u, 4196416u, 2112u, 272629824u, 4196352u, 268435520u, 268435456u, 4196352u, 268435520u, 272631808u, 272631808u, 268435456u, 268437504u, 4194304u, 4194368u, 2112u, 268435456u, 4196352u, 4196352u, 268435520u, 64u, 272631872u, 268437568u, 272629760u, 2048u, 4194368u, 272629824u, 2048u, 272631808u, 268435456u, 0u, 4196416u, 2112u, 272629824u, 268437504u, 4194304u, 272631872u, 268437504u, 4194304u, 64u, 272629760u, 0u, 4196416u, 268437568u, 4194368u, 2112u, 268435520u, 272631808u},
  {67174656u, 260u, 260u, 0u, 67109124u, 65536u, 67108864u, 67174660u, 67174404u, 67174656u, 65536u, 67108868u, 4u, 67108864u, 67174660u, 65792u, 0u, 67174404u, 67174400u, 67109124u, 65540u, 67109120u, 256u, 65540u, 67109120u, 65796u, 65796u, 256u, 65792u, 4u, 67108868u, 67174400u, 256u, 65540u, 65540u, 67109120u, 67108864u, 67174660u, 67174656u, 260u, 65536u, 67108868u, 67109124u, 65536u, 65796u, 256u, 0u, 67174404u, 67174400u, 67109124u, 65792u, 4u, 67174660u, 65792u, 4u, 67108864u, 260u, 0u, 67174404u, 67174656u, 67108868u, 67174400u, 67109120u, 65796u},
  {1074806784u, 1048704u, 1048704u, 0u, 1065088u, 1073741824u, 16384u, 1074806912u, 1073758336u, 1074806784u, 1073741824u, 16512u, 128u, 16384u, 1074806912u, 1074790400u, 0u, 1073758336u, 1073758208u, 1065088u, 1073741952u, 1064960u, 1048576u, 1073741952u, 1064960u, 1074790528u, 1074790528u, 1048576u, 1074790400u, 128u, 16512u, 1073758208u, 1048576u, 1073741952u, 1073741952u, 1064960u, 16384u, 1074806912u, 1074806784u, 1048704u, 1073741824u, 16512u, 1065088u, 1073741824u, 1074790528u, 1048576u, 0u, 1073758336u, 1073758208u, 1065088u, 1074790400u, 128u, 1074806912u, 1074790400u, 128u, 16384u, 1048704u, 0u, 1073758336u, 1074806784u, 16512u, 1073758208u, 1064960u, 1074790528u},
  {2147484673u, 1056u, 1056u, 0u, 2147484704u, 1u, 2147483648u, 2147484705u, 2147483681u, 2147484673u, 1u, 2147483680u, 32u, 2147483648u, 2147484705u, 1025u, 0u, 2147483681u, 2147483649u, 2147484704u, 33u, 2147484672u, 1024u, 33u, 2147484672u, 1057u, 1057u, 1024u, 1025u, 32u, 2147483680u, 2147483649u, 1024u, 33u, 33u, 2147484672u, 2147483648u, 2147484705u, 2147484673u, 1056u, 1u, 2147483680u, 2147484704u, 1u, 1057u, 1024u, 0u, 2147483681u, 2147483649u, 2147484704u, 1025u, 32u, 2147484705u, 1025u, 32u, 2147483648u, 1056u, 0u, 2147483681u, 2147484673u, 2147483680u, 2147483649u, 2147484672u, 1057u},
  {134225936u, 136314880u, 136314880u, 0u, 136323072u, 16u, 8192u, 136323088u, 2105360u, 134225936u, 16u, 2105344u, 2097152u, 8192u, 136323088u, 134217744u, 0u, 2105360u, 8208u, 136323072u, 2097168u, 134225920u, 134217728u, 2097168u, 134225920u, 136314896u, 136314896u, 134217728u, 134217744u, 2097152u, 2105344u, 8208u, 134217728u, 2097168u, 2097168u, 134225920u, 8192u, 136323088u, 134225936u, 136314880u, 16u, 2105344u, 136323072u, 16u, 136314896u, 134217728u, 0u, 2105360u, 8208u, 136323072u, 134217744u, 2097152u, 136323088u, 134217744u, 2097152u, 8192u, 136314880u, 0u, 2105360u, 134225936u, 2105344u, 8208u, 134225920u, 136314896u},
  {17043456u, 4098u, 4098u, 0u, 266242u, 16777216u, 262144u, 17043458u, 17039362u, 17043456u, 16777216u, 262146u, 2u, 262144u, 17043458u, 16781312u, 0u, 17039362u, 17039360u, 266242u, 16777218u, 266240u, 4096u, 16777218u, 266240u, 16781314u, 16781314u, 4096u, 16781312u, 2u, 262146u, 17039360u, 4096u, 16777218u, 16777218u, 266240u, 262144u, 17043458u, 17043456u, 4098u, 16777216u, 262146u, 266242u, 16777216u, 16781314u, 4096u, 0u, 17039362u, 17039360u, 266242u, 16781312u, 2u, 17043458u, 16781312u, 2u, 262144u, 4098u, 0u, 17039362u, 17043456u, 262146u, 17039360u, 266240u, 16781314u},
  {536871432u, 537395200u, 537395200u, 0u, 537395712u, 8u, 512u, 537395720u, 524808u, 536871432u, 8u, 524800u, 524288u, 512u, 537395720u, 536870920u, 0u, 524808u, 520u, 537395712u, 524296u, 536871424u, 536870912u, 524296u, 536871424u, 537395208u, 537395208u, 536870912u, 536870920u, 524288u, 524800u, 520u, 536870912u, 524296u, 524296u, 536871424u, 512u, 537395720u, 536871432u, 537395200u, 8u, 524800u, 537395712u, 8u, 537395208u, 536870912u, 0u, 524808u, 520u, 537395712u, 536870920u, 524288u, 537395720u, 536870920u, 524288u, 512u, 537395200u, 0u, 524808u, 536871432u, 524800u, 520u, 536871424u, 537395208u}
};

static const uint32_t des_sbox[8][64] = {
  {8552448u, 0u, 8388608u, 42106880u, 41975808u, 42074112u, 33554432u, 8388608u, 131072u, 8552448u, 42106880u, 131072u, 33718272u, 41975808u, 32768u, 33554432u, 33685504u, 163840u, 163840u, 8519680u, 8519680u, 8421376u, 8421376u, 33718272u, 41943040u, 33587200u, 33587200u, 41943040u, 0u, 33685504u, 42074112u, 32768u, 8388608u, 42106880u, 33554432u, 8421376u, 8552448u, 32768u, 32768u, 131072u, 41975808u, 8388608u, 8519680u, 33587200u, 131072u, 33554432u, 33718272u, 42074112u, 42106880u, 41943040u, 8421376u, 33718272u, 33587200u, 33685504u, 42074112u, 8552448u, 33685504u, 163840u, 163840u, 0u, 41943040u, 8519680u, 0u, 41975808u},
  {272631872u, 4194368u, 4194304u, 272631808u, 2048u, 268435456u, 268437568u, 272629824u, 268435520u, 272631872u, 4196416u, 64u, 4194368u, 2048u, 268435456u, 268437568u, 4196352u, 268437504u, 272629824u, 0u, 64u, 4194304u, 272631808u, 2112u, 268437504u, 268435520u, 0u, 4196352u, 272629760u, 4196416u, 2112u, 272629760u, 0u, 272631808u, 268437568u, 2048u, 272629824u, 2112u, 4196416u, 4194304u, 2112u, 4194368u, 268435456u, 272631872u, 272631808u, 268435456u, 4194304u, 64u, 272629760u, 4196416u, 2048u, 268435520u, 268437504u, 272629824u, 268435520u, 268437504u, 4196352u, 0u, 4194368u, 272629760u, 64u, 268437568u, 272631872u, 4196352u},
  {67174400u, 65796u, 0u, 67109124u, 65540u, 0u, 67174656u, 65540u, 67109120u, 67108868u, 67108868u, 256u, 67174660u, 67109120u, 260u, 67174400u, 4u, 67108864u, 65796u, 65536u, 65792u, 260u, 67109124u, 67174656u, 67174404u, 65792u, 256u, 67174404u, 67108864u, 67174660u, 65536u, 4u, 65796u, 4u, 67109120u, 67174400u, 256u, 65796u, 65540u, 0u, 65536u, 67109120u, 67174660u, 65540u, 67108868u, 65536u, 0u, 67109124u, 67174404u, 256u, 4u, 67174660u, 67108864u, 67174656u, 65792u, 67108868u, 260u, 67174404u, 67174400u, 260u, 67174656u, 67108864u, 67109124u, 65792u},
  {1065088u, 1074790528u, 1074790528u, 1073741824u, 1074806784u, 1073758336u, 16512u, 1048704u, 0u, 1064960u, 1064960u, 1074806912u, 1073741952u, 0u, 1073758208u, 16512u, 128u, 1048576u, 16384u, 1065088u, 1073741824u, 16384u, 1048704u, 1074790400u, 1073758336u, 128u, 1074790400u, 1073758208u, 1048576u, 1074806784u, 1074806912u, 1073741952u, 1073758208u, 16512u, 1064960u, 1074806912u, 1073741952u, 0u, 0u, 1064960u, 1074790400u, 1073758208u, 1073758336u, 128u, 1065088u, 1074790528u, 1074790528u, 1073741824u, 1074806912u, 1073741952u, 128u, 1048576u, 16512u, 1048704u, 1074806784u, 1073758336u, 1048704u, 1074790400u, 16384u, 1065088u, 1073741824u, 16384u, 1048576u, 1074806784u},
  {2147483648u, 2147484673u, 1025u, 2147483681u, 1024u, 2147483648u, 32u, 1025u, 2147484704u, 1024u, 2147483649u, 2147484704u, 2147483681u, 1057u, 2147484672u, 32u, 1u, 1056u, 1056u, 0u, 2147483680u, 2147484705u, 2147484705u, 2147483649u, 1057u, 2147483680u, 0u, 33u, 2147484673u, 1u, 33u, 2147484672u, 1024u, 2147483681u, 2147483648u, 1u, 32u, 1025u, 2147483681u, 2147484704u, 2147483649u, 32u, 1057u, 2147484673u, 2147484704u, 2147483648u, 1u, 1057u, 2147484705u, 2147484672u, 33u, 2147484705u, 1025u, 0u, 1056u, 33u, 2147484672u, 2147483649u, 2147483680u, 1024u, 0u, 1056u, 2147484673u, 2147483680u},
  {134217744u, 8208u, 2097152u, 136323088u, 8208u, 134217728u, 136323088u, 8192u, 2097168u, 136323072u, 8192u, 134217744u, 134225920u, 2097168u, 16u, 136314880u, 0u, 134225920u, 136314896u, 2097152u, 2105344u, 136314896u, 134217728u, 134225936u, 134225936u, 0u, 136323072u, 2105360u, 136314880u, 2105344u, 2105360u, 16u, 2097168u, 134217728u, 134225936u, 2105344u, 136323088u, 8192u, 136314880u, 134217744u, 8192u, 2097168u, 16u, 136314880u, 134217744u, 136323088u, 2105344u, 8208u, 136323072u, 2105360u, 0u, 134225936u, 134217728u, 2097152u, 8208u, 136323072u, 2097152u, 134225920u, 136314896u, 0u, 2105360u, 16u, 134225920u, 136314896u},
  {4096u, 16781314u, 17039362u, 0u, 262144u, 17039362u, 17043456u, 266242u, 17043458u, 4096u, 0u, 16777218u, 16777216u, 2u, 16781314u, 17039360u, 262146u, 17043456u, 16781312u, 262146u, 16777218u, 4098u, 266242u, 16781312u, 4098u, 262144u, 17039360u, 17043458u, 266240u, 16777216u, 2u, 266240u, 2u, 266240u, 4096u, 17039362u, 17039362u, 16781314u, 16781314u, 16777216u, 16781312u, 2u, 262146u, 4096u, 266242u, 17039360u, 17043456u, 266242u, 17039360u, 16777218u, 17043458u, 4098u, 266240u, 0u, 16777216u, 17043458u, 0u, 17043456u, 4098u, 262144u, 16777218u, 262146u, 262144u, 16781312u},
  {537395208u, 524288u, 512u, 537395720u, 8u, 537395208u, 536870912u, 8u, 536871424u, 520u, 537395720u, 524800u, 524808u, 537395712u, 524288u, 536870912u, 520u, 536870920u, 524296u, 537395200u, 524800u, 536871424u, 536871432u, 524808u, 537395200u, 0u, 0u, 536871432u, 536870920u, 524296u, 537395712u, 512u, 537395712u, 512u, 524808u, 524288u, 536870912u, 536871432u, 524288u, 537395712u, 524296u, 536870912u, 536870920u, 520u, 536871432u, 8u, 512u, 537395208u, 0u, 537395720u, 536871424u, 536870920u, 520u, 524296u, 537395208u, 0u, 537395720u, 524800u, 524800u, 537395200u, 537395200u, 536871424u, 8u, 524808u}
};

static void PC1_bits(const uint8_t *in, uint8_t *out)
{
	out[0]= BITNUM(in,56,7) | BITNUM(in,48,6) | BITNUM(in,40,5) | BITNUM(in,32,4) | BITNUM(in,24,3) | BITNUM(in,16,2) | BITNUM(in,8,1) | BITNUM(in,0,0);
	out[1]= BITNUM(in,57,7) | BITNUM(in,49,6) | BITNUM(in,41,5) | BITNUM(in,33,4) | BITNUM(in,25,3) | BITNUM(in,17,2) | BITNUM(in,9,1) | BITNUM(in,1,0);
	out[2]= BITNUM(in,58,7) | BITNUM(in,50,6) | BITNUM(in,42,5) | BITNUM(in,34,4) | BITNUM(in,26,3) | BITNUM(in,18,2) | BITNUM(in,10,1) | BITNUM(in,2,0);
	out[3]= BITNUM(in,59,7) | BITNUM(in,51,6) | BITNUM(in,43,5) | BITNUM(in,35,4) | BITNUM(in,62,3) | BITNUM(in,54,2) | BITNUM(in,46,1) | BITNUM(in,38,0);
	out[4]= BITNUM(in,30,7) | BITNUM(in,22,6) | BITNUM(in,14,5) | BITNUM(in,6,4) | BITNUM(in,61,3) | BITNUM(in,53,2) | BITNUM(in,45,1) | BITNUM(in,37,0);
	out[5]= BITNUM(in,29,7) | BITNUM(in,21,6) | BITNUM(in,13,5) | BITNUM(in,5,4) | BITNUM(in,60,3) | BITNUM(in,52,2) | BITNUM(in,44,1) | BITNUM(in,36,0);
	out[6]= BITNUM(in,28,7) | BITNUM(in,20,6) | BITNUM(in,12,5) | BITNUM(in,4,4) | BITNUM(in,27,3) | BITNUM(in,19,2) | BITNUM(in,11,1) | BITNUM(in,3,0);
}

static void PC2_bits(const uint8_t *in, uint8_t *out)
{
	out[0]= BITNUM(in,13,7) | BITNUM(in,16,6) | BITNUM(in,10,5) | BITNUM(in,23,4) | BITNUM(in,0,3) | BITNUM(in,4,2) | BITNUM(in,2,1) | BITNUM(in,27,0);
	out[1]= BITNUM(in,14,7) | BITNUM(in,5,6) | BITNUM(in,20,5) | BITNUM(in,9,4) | BITNUM(in,22,3) | BITNUM(in,18,2) | BITNUM(in,11,1) | BITNUM(in,3,0);
	out[2]= BITNUM(in,25,7) | BITNUM(in,7,6) | BITNUM(in,15,5) | BITNUM(in,6,4) | BITNUM(in,26,3) | BITNUM(in,19,2) | BITNUM(in,12,1) | BITNUM(in,1,0);
	out[3]= BITNUM(in,40,7) | BITNUM(in,51,6) | BITNUM(in,30,5) | BITNUM(in,36,4) | BITNUM(in,46,3) | BITNUM(in,54,2) | BITNUM(in,29,1) | BITNUM(in,39,0);
	out[4]= BITNUM(in,50,7) | BITNUM(in,44,6) | BITNUM(in,32,5) | BITNUM(in,47,4) | BITNUM(in,43,3) | BITNUM(in,48,2) | BITNUM(in,38,1) | BITNUM(in,55,0);
	out[5]= BITNUM(in,33,7) | BITNUM(in,52,6) | BITNUM(in,45,5) | BITNUM(in,41,4) | BITNUM(in,49,3) | BITNUM(in,35,2) | BITNUM(in,28,1) | BITNUM(in,31,0);
}

static void IP_bits(uint8_t *block)
{
  uint8_t tmp[8];
  tmp[0] = BITNUM(block,57,7) | BITNUM(block,49,6) | BITNUM(block,41,5) | BITNUM(block,33,4) | BITNUM(block,25,3) | BITNUM(block,17,2) | BITNUM(block,9,1) | BITNUM(block,1,0);
  tmp[1] = BITNUM(block,59,7) | BITNUM(block,51,6) | BITNUM(block,43,5) | BITNUM(block,35,4) | BITNUM(block,27,3) | BITNUM(block,19,2) | BITNUM(block,11,1) | BITNUM(block,3,0);
  tmp[2] = BITNUM(block,61,7) | BITNUM(block,53,6) | BITNUM(block,45,5) | BITNUM(block,37,4) | BITNUM(block,29,3) | BITNUM(block,21,2) | BITNUM(block,13,1) | BITNUM(block,5,0);
  tmp[3] = BITNUM(block,63,7) | BITNUM(block,55,6) | BITNUM(block,47,5) | BITNUM(block,39,4) | BITNUM(block,31,3) | BITNUM(block,23,2) | BITNUM(block,15,1) | BITNUM(block,7,0);
  tmp[4] = BITNUM(block,56,7) | BITNUM(block,48,6) | BITNUM(block,40,5) | BITNUM(block,32,4) | BITNUM(block,24,3) | BITNUM(block,16,2) | BITNUM(block,8,1) | BITNUM(block,0,0);
  tmp[5] = BITNUM(block,58,7) | BITNUM(block,50,6) | BITNUM(block,42,5) | BITNUM(block,34,4) | BITNUM(block,26,3) | BITNUM(block,18,2) | BITNUM(block,10,1) | BITNUM(block,2,0);
  tmp[6] = BITNUM(block,60,7) | BITNUM(block,52,6) | BITNUM(block,44,5) | BITNUM(block,36,4) | BITNUM(block,28,3) | BITNUM(block,20,2) | BITNUM(block,12,1) | BITNUM(block,4,0);
  tmp[7] = BITNUM(block,62,7) | BITNUM(block,54,6) | BITNUM(block,46,5) | BITNUM(block,38,4) | BITNUM(block,30,3) | BITNUM(block,22,2) | BITNUM(block,14,1) | BITNUM(block,6,0);
  memcpy(block, tmp, 8);
}

static void invIP_bits(uint8_t *block)
{
  uint8_t tmp[8];
  tmp[0] = BITNUM(block,39,7) | BITNUM(block,7,6) | BITNUM(block,47,5) | BITNUM(block,15,4) | BITNUM(block,55,3) | BITNUM(block,23,2) | BITNUM(block,63,1) | BITNUM(block,31,0);
  tmp[1] = BITNUM(block,38,7) | BITNUM(block,6,6) | BITNUM(block,46,5) | BITNUM(block,14,4) | BITNUM(block,54,3) | BITNUM(block,22,2) | BITNUM(block,62,1) | BITNUM(block,30,0);
  tmp[2] = BITNUM(block,37,7) | BITNUM(block,5,6) | BITNUM(block,45,5) | BITNUM(block,13,4) | BITNUM(block,53,3) | BITNUM(block,21,2) | BITNUM(block,61,1) | BITNUM(block,29,0);
  tmp[3] = BITNUM(block,36,7) | BITNUM(block,4,6) | BITNUM(block,44,5) | BITNUM(block,12,4) | BITNUM(block,52,3) | BITNUM(block,20,2) | BITNUM(block,60,1) | BITNUM(block,28,0);
  tmp[4] = BITNUM(block,35,7) | BITNUM(block,3,6) | BITNUM(block,43,5) | BITNUM(block,11,4) | BITNUM(block,51,3) | BITNUM(block,19,2) | BITNUM(block,59,1) | BITNUM(block,27,0);
  tmp[5] = BITNUM(block,34,7) | BITNUM(block,2,6) | BITNUM(block,42,5) | BITNUM(block,10,4) | BITNUM(block,50,3) | BITNUM(block,18,2) | BITNUM(block,58,1) | BITNUM(block,26,0);
  tmp[6] = BITNUM(block,33,7) | BITNUM(block,1,6) | BITNUM(block,41,5) | BITNUM(block,9,4) | BITNUM(block,49,3) | BITNUM(block,17,2) | BITNUM(block,57,1) | BITNUM(block,25,0);
  tmp[7] = BITNUM(block,32,7) | BITNUM(block,0,6) | BITNUM(block,40,5) | BITNUM(block,8,4) | BITNUM(block,48,3) | BITNUM(block,16,2) | BITNUM(block,56,1) | BITNUM(block,24,0);
  memcpy(block, tmp, 8);
}

/* CrypTool macOS port: the bit permutations above are linear, so they can be
 * evaluated byte-wise with lookup tables generated from the original functions
 * (8 table lookups instead of 64 single-bit operations). */
static uint64_t ip_tab[8][256], fp_tab[8][256], pc1_tab[8][256], pc2_tab[7][256];
static pthread_once_t perm_once = PTHREAD_ONCE_INIT;

static uint64_t bytes_to_u64(const uint8_t *b, int n)
{
	uint64_t v = 0;
	int i;
	for (i = 0; i < n; i++) v = (v << 8) | b[i];
	return v << (8 * (8 - n));
}

static void u64_to_bytes(uint64_t v, uint8_t *b, int n)
{
	int i;
	for (i = 0; i < n; i++) b[i] = (uint8_t)(v >> (56 - 8 * i));
}

static void build_perm_tables(void)
{
	int pos, val;
	for (pos = 0; pos < 8; pos++) {
		for (val = 0; val < 256; val++) {
			uint8_t in[8] = { 0 }, out[8] = { 0 };
			in[pos] = (uint8_t)val;
			memcpy(out, in, 8); IP_bits(out); ip_tab[pos][val] = bytes_to_u64(out, 8);
			memcpy(out, in, 8); invIP_bits(out); fp_tab[pos][val] = bytes_to_u64(out, 8);
			memset(out, 0, 8); PC1_bits(in, out); pc1_tab[pos][val] = bytes_to_u64(out, 7);
			if (pos < 7) { memset(out, 0, 8); PC2_bits(in, out); pc2_tab[pos][val] = bytes_to_u64(out, 6); }
		}
	}
}

static inline uint64_t perm_lookup(uint64_t tab[][256], const uint8_t *in, int n)
{
	uint64_t v = 0;
	int i;
	for (i = 0; i < n; i++) v |= tab[i][in[i]];
	return v;
}

static inline void IP(uint8_t *block) { u64_to_bytes(perm_lookup(ip_tab, block, 8), block, 8); }
static inline void invIP(uint8_t *block) { u64_to_bytes(perm_lookup(fp_tab, block, 8), block, 8); }
static inline void PC1(const uint8_t *in, uint8_t *out) { u64_to_bytes(perm_lookup(pc1_tab, in, 8), out, 7); }
static inline void PC2(const uint8_t *in, uint8_t *out) { u64_to_bytes(perm_lookup(pc2_tab, in, 7), out, 6); }

static inline uint32_t load_le32(const uint8_t *p)
{
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static inline void store_le32(uint8_t *p, uint32_t v)
{
	p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24);
}

/* One DES round function f(R, K) using the combined S-box/P tables. The
 * 32-bit half is handled as 4 bytes b32[0..3] in block order, the table values
 * are the little-endian images of the permuted S-box outputs (as in CT1). */
static inline uint32_t desxl_f(const uint32_t sbox[8][64], uint32_t r, const uint8_t *k)
{
	uint8_t b32[4];
	store_le32(b32, r);
	return sbox[0][(((b32[3]&0x01)<<5) | ((b32[0]>>3)&0x1f))  ^  ((k[0]>>2)&0x3f)]
	     ^ sbox[1][(((b32[0]&0x1f)<<1) | ((b32[1]>>7)&0x01))  ^  (((k[0]&0x03)<<4) | ((k[1]>>4)&0x0f))]
	     ^ sbox[2][(((b32[0]&0x01)<<5) | ((b32[1]>>3)&0x1f))  ^  (((k[1]&0x0f)<<2) | ((k[2]>>6)&0x03))]
	     ^ sbox[3][(((b32[1]&0x1f)<<1) | ((b32[2]>>7)&0x01))  ^  (k[2]&0x3f)]
	     ^ sbox[4][(((b32[1]&0x01)<<5) | ((b32[2]>>3)&0x1f))  ^  ((k[3]>>2)&0x3f)]
	     ^ sbox[5][(((b32[2]&0x1f)<<1) | ((b32[3]>>7)&0x01))  ^  (((k[3]&0x03)<<4) | ((k[4]>>4)&0x0f))]
	     ^ sbox[6][(((b32[2]&0x01)<<5) | ((b32[3]>>3)&0x1f))  ^  (((k[4]&0x0f)<<2) | ((k[5]>>6)&0x03))]
	     ^ sbox[7][(((b32[3]&0x1f)<<1) | ((b32[0]>>7)&0x01))  ^  (k[5]&0x3f)];
}

static void cryptBlock(const desxl_ctx *ctx, uint8_t *block, int mode, ctc_desxl_variant variant)
{
	int i, x;
	uint32_t l, r, t;
	const int lightweight = (variant == CTC_VARIANT_DESL || variant == CTC_VARIANT_DESXL);
	const int whitening = (variant == CTC_VARIANT_DESX || variant == CTC_VARIANT_DESXL);
	const uint32_t (*sbox)[64] = lightweight ? desl_sbox : des_sbox;

	if (whitening) {
		x = (mode == DXL_ENCRYPT) ? 0 : 1;
		for (i = 0; i < 8; i++) block[i] ^= ctx->desxkey[x][i];
	}
	if (!lightweight) IP(block);
	l = load_le32(block);
	r = load_le32(block + 4);
	for (i = 1; i <= 16; i++) {
		const uint8_t *k = (mode == DXL_ENCRYPT) ? ctx->roundkey[i - 1] : ctx->roundkey[16 - i];
		t = desxl_f(sbox, r, k) ^ l;
		l = r;
		r = t;
	}
	/* final swap */
	store_le32(block, r);
	store_le32(block + 4, l);
	if (!lightweight) invIP(block);
	if (whitening) {
		x = (mode == DXL_ENCRYPT) ? 1 : 0;
		for (i = 0; i < 8; i++) block[i] ^= ctx->desxkey[x][i];
	}
}

static void createKey(desxl_ctx *ctx, const uint8_t *key, ctc_desxl_variant variant)
{
	uint8_t redKey[7];
	uint32_t c, d, x;
	int i;
	if (variant == CTC_VARIANT_DESX || variant == CTC_VARIANT_DESXL) {
		memcpy(ctx->desxkey[0], key + 8, 8);
		memcpy(ctx->desxkey[1], key + 16, 8);
	}
	PC1(key, redKey);
	c = ((uint32_t)redKey[0]<<20) | ((uint32_t)redKey[1]<<12) | ((uint32_t)redKey[2]<<4) | ((uint32_t)redKey[3]>>4);
	d = (((uint32_t)redKey[3]&0xf)<<24) | ((uint32_t)redKey[4]<<16) | ((uint32_t)redKey[5]<<8) | (uint32_t)redKey[6];
	for (i = 1; i <= 16; i++) {
		if (i == 1 || i == 2 || i == 9 || i == 16) {
			x = (c>>27)&1; c = ((c<<1)|x)&0xfffffff;
			x = (d>>27)&1; d = ((d<<1)|x)&0xfffffff;
		} else {
			x = (c>>26)&3; c = ((c<<2)|x)&0xfffffff;
			x = (d>>26)&3; d = ((d<<2)|x)&0xfffffff;
		}
		redKey[0] = (uint8_t)((c>>20)&0xff);
		redKey[1] = (uint8_t)((c>>12)&0xff);
		redKey[2] = (uint8_t)((c>>4)&0xff);
		redKey[3] = (uint8_t)(((c<<4)&0xf0) | ((d>>24)&0x0f));
		redKey[4] = (uint8_t)((d>>16)&0xff);
		redKey[5] = (uint8_t)((d>>8)&0xff);
		redKey[6] = (uint8_t)(d&0xff);
		PC2(redKey, ctx->roundkey[i-1]);
	}
}

int ctc_desxl_cbc(ctc_desxl_variant variant, int decrypt, const uint8_t *key, size_t keyLen,
                  const uint8_t *iv8, const uint8_t *in, uint8_t *out, size_t len)
{
	desxl_ctx ctx;
	uint8_t chain[8] = { 0 }, b[8], c[8];
	size_t off;
	int i;
	size_t needed = (variant == CTC_VARIANT_DESX || variant == CTC_VARIANT_DESXL) ? 24 : 8;

	if (variant < CTC_VARIANT_DESX || variant > CTC_VARIANT_DES)
		return CTC_ERR_KEY;
	if (keyLen != needed)
		return CTC_ERR_KEY;
	if (len % 8)
		return CTC_ERR_LENGTH;
	pthread_once(&perm_once, build_perm_tables);
	memset(&ctx, 0, sizeof ctx);
	createKey(&ctx, key, variant);
	if (iv8)
		memcpy(chain, iv8, 8);

	for (off = 0; off < len; off += 8) {
		memcpy(b, in + off, 8);
		if (!decrypt) {
			for (i = 0; i < 8; i++) b[i] ^= chain[i];
			cryptBlock(&ctx, b, DXL_ENCRYPT, variant);
			memcpy(chain, b, 8);
		} else {
			memcpy(c, b, 8);
			cryptBlock(&ctx, b, DXL_DECRYPT, variant);
			for (i = 0; i < 8; i++) b[i] ^= chain[i];
			memcpy(chain, c, 8);
		}
		memcpy(out + off, b, 8);
	}
	return CTC_OK;
}

/* CrypTool macOS port: single DES / Triple DES (EDE, 2 or 3 keys), ECB or CBC, using the
 * DES of this file (no CommonCrypto key setup per call – used by the brute-force analysis). */
int ctc_des_crypt(int decrypt, int cbc, const uint8_t *key, size_t keyLen, const uint8_t *iv8,
                  const uint8_t *in, uint8_t *out, size_t len)
{
	desxl_ctx k1, k2, k3;
	uint8_t chain[8] = { 0 }, b[8], c[8];
	size_t off;
	int i, triple;

	if (keyLen != 8 && keyLen != 16 && keyLen != 24)
		return CTC_ERR_KEY;
	if (len % 8)
		return CTC_ERR_LENGTH;
	triple = keyLen > 8;
	pthread_once(&perm_once, build_perm_tables);
	createKey(&k1, key, CTC_VARIANT_DES);
	if (triple) {
		createKey(&k2, key + 8, CTC_VARIANT_DES);
		createKey(&k3, keyLen == 24 ? key + 16 : key, CTC_VARIANT_DES);
	}
	if (iv8)
		memcpy(chain, iv8, 8);

	for (off = 0; off < len; off += 8) {
		memcpy(b, in + off, 8);
		if (!decrypt) {
			if (cbc)
				for (i = 0; i < 8; i++) b[i] ^= chain[i];
			cryptBlock(&k1, b, DXL_ENCRYPT, CTC_VARIANT_DES);
			if (triple) {
				cryptBlock(&k2, b, DXL_DECRYPT, CTC_VARIANT_DES);
				cryptBlock(&k3, b, DXL_ENCRYPT, CTC_VARIANT_DES);
			}
			memcpy(chain, b, 8);
		} else {
			memcpy(c, b, 8);
			if (triple) {
				cryptBlock(&k3, b, DXL_DECRYPT, CTC_VARIANT_DES);
				cryptBlock(&k2, b, DXL_ENCRYPT, CTC_VARIANT_DES);
			}
			cryptBlock(&k1, b, DXL_DECRYPT, CTC_VARIANT_DES);
			if (cbc)
				for (i = 0; i < 8; i++) b[i] ^= chain[i];
			memcpy(chain, c, 8);
		}
		memcpy(out + off, b, 8);
	}
	return CTC_OK;
}

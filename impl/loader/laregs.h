// ------------------------------------------------------------------------------------//
//  Copyright (c) 2026 Loongson Technology Corporation Limited.
//
//  OpenLACores is licensed under Mulan PSL v2.
// 
//  You can use this software according to the terms and conditions of the Mulan PSL v2.
//
//  You may obtain a copy of Mulan PSL v2 at:
//           http://license.coscl.org.cn/MulanPSL2
// 
//  THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
//  KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
//  NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// 
//  See the Mulan PSL v2 for more details.
// ------------------------------------------------------------------------------------//

#ifndef _ASM_LAREGS_H
#define _ASM_LAREGS_H

#define LA_CSR_CRMD		0x0		/* Current mode info */
#define LA_CSR_PRMD		0x1		/* Prev-exception mode info */
#define LA_CSR_EUEN		0x2		/* Extended unit enable */
#define LA_CSR_MISC		0x3		/* Misc config */
#define LA_CSR_ECFG		0x4		/* Exception config */
#define LA_CSR_ESTAT	0x5		/* Exception status */
#define LA_CSR_ERA		0x6		/* ERA */
#define LA_CSR_BADV		0x7		/* Bad virtual address */
#define LA_CSR_BADI		0x8		/* Bad instruction */
#define LA_CSR_EENTRY	0xc		/* Exception entry base address */
#define LA_CSR_TLBIDX	0x10	/* TLB Index, EHINV, PageSize, NP */
#define LA_CSR_TLBEHI	0x11	/* TLB EntryHi */
#define LA_CSR_TLBELO0	0x12	/* TLB EntryLo0 */
#define LA_CSR_TLBELO1	0x13	/* TLB EntryLo1 */
#define LA_CSR_GTLBC	0x15	/* Guest TLB control */
#define LA_CSR_ASID		0x18	/* ASID */
#define LA_CSR_PGDL		0x19	/* Page table base address when VA[47] = 0 */
#define LA_CSR_PGDH		0x1a	/* Page table base address when VA[47] = 1 */
#define LA_CSR_PGD		0x1b	/* Page table base */
#define LA_CSR_PWCTL0		0x1c	/* PWCtl0 */
#define LA_CSR_PWCTL1		0x1d	/* PWCtl1 */
#define LA_CSR_STLBPGSIZE	0x1e
#define LA_CSR_RVACFG		0x1f
#define LA_CSR_CPUID		0x20	/* CPU core number */
#define LA_CSR_PRCFG1	0x21	/* Config1 */
#define LA_CSR_PRCFG2	0x22	/* Config2 */
#define LA_CSR_PRCFG3	0x23	/* Config3 */

/* Kscratch registers */
#define LA_CSR_KS0		0x30
#define LA_CSR_KS1		0x31
#define LA_CSR_KS2		0x32
#define LA_CSR_KS3		0x33
#define LA_CSR_KS4		0x34
#define LA_CSR_KS5		0x35
#define LA_CSR_KS6		0x36
#define LA_CSR_KS7		0x37
#define LA_CSR_KS8		0x38

/* Timer registers */
#define LA_CSR_TMID		0x40	/* Timer ID */
#define LA_CSR_TCFG		0x41	/* Timer config */
#define LA_CSR_TVAL		0x42	/* Timer value */
#define LA_CSR_CNTC		0x43	/* Timer offset */
#define LA_CSR_TINTCLR	0x44	/* Timer interrupt clear */
#define LA_CSR_LLBCTL	0x60	/* LLBit control */
#define LA_CSR_IMPCTL1	0x80	/* Loongson config1 */
#define LA_CSR_IMPCTL2	0x81	/* Loongson config2 */
#define LA_CSR_GNMI		0x82

/* TLB refill registers */
#define LA_CSR_TLBRENTRY	0x88	/* TLB refill exception base address */
#define LA_CSR_TLBRBADV		0x89	/* TLB refill badvaddr */
#define LA_CSR_TLBRERA		0x8a	/* TLB refill ERA */
#define LA_CSR_TLBRSAVE		0x8b	/* KScratch for TLB refill exception */
#define LA_CSR_TLBRELO0		0x8c	/* TLB refill entrylo0 */
#define LA_CSR_TLBRELO1		0x8d	/* TLB refill entrylo1 */
#define LA_CSR_TLBREHI		0x8e	/* TLB refill entryhi */
#define LA_CSR_TLBRPRMD		0x8f	/* TLB refill mode info */


/* Machine error registers */
#define LA_CSR_ERRCTL		0x90	/* ERRCTL */
#define LA_CSR_ERRINFO1		0x91	/* Error info1 */
#define LA_CSR_ERRINFO2		0x92	/* Error info2 */
#define LA_CSR_MERRENTRY	0x93	/* Error exception base address */
#define LA_CSR_MERRERA		0x94	/* Error exception PC */
#define LA_CSR_ERRSAVE		0x95	/* KScratch for machine error exception */


/* Direct map windows registers */
#define LA_CSR_DMWIN0		0x180	/* Direct map window 0 */
#define LA_CSR_DMWIN1		0x181	/* Direct map window 1 */


#endif /* _ASM_LAREGS_H */

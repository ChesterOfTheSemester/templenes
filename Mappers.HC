class memory_manager {
U8 *RAM;
U8 *VRAM;
U8 *OAM;

U8 w;
U16 t;
U16 x;
U16 y;

U16 VRAM_address;
U8 internal_buffer;
};

memory_manager MMU;

// Mapper #1 [MMC1]

// 5-bit buffer:
I64 MMC1_regBuffer = 0;
I64 MMC1_regBufferCounter = 0;
// Register 0:
I64 MMC1_mirroring = 0;
I64 MMC1_oneScreenMirroring = 0;
I64 MMC1_prgSwitchingArea = 1;
I64 MMC1_prgSwitchingSize = 1;
I64 MMC1_vromSwitchingSize = 0;
// Register 1:
I64 MMC1_romSelectionReg0 = 0;
// Register 2:
I64 MMC1_romSelectionReg1 = 0;
// Register 3:
I64 MMC1_romBankSelect = 0;

I64 MMC1_getRegNumber(U16 address)
{
	if (address >= 0x8000 && address <= 0x9fff) {
		return 0;
	} else if (address >= 0xa000 && address <= 0xbfff) {
		return 1;
	} else if (address >= 0xc000 && address <= 0xdfff) {
		return 2;
	} else {
		return 3;
	}
}

U0 MMC1_loadRomBank(I64 bank, U16 address)
{

}

U0 MMC1_loadVromBank(I64 bank, U16 address)
{

}

U0 MMC1_load32kRomBank(I64 bank, U16 address)
{

}

U0 MMC1_load8kVromBank(I64 bank, U16 address)
{

}

U0 MMC1_setReg(I64 _reg, I64 value)
{
	I64 tmp;
	switch (_reg) {
	case 0:
		// Mirroring:
		tmp = value & 3;
		if (tmp != MMC1_mirroring) {
			// Set mirroring:
			MMC1_mirroring = tmp;
			/* TODO: mirroring
			   if ((MMC1_mirroring & 2) == 0) {
			   // SingleScreen mirroring overrides the other setting:
			   MMC1_nes.ppu.setMirroring(MMC1_nes.rom.SINGLESCREEN_MIRRORING);
			   } else if ((MMC1_mirroring & 1) != 0) {
			   // Not overridden by SingleScreen mirroring.
			   MMC1_nes.ppu.setMirroring(MMC1_nes.rom.HORIZONTAL_MIRRORING);
			   } else {
			   MMC1_nes.ppu.setMirroring(MMC1_nes.rom.VERTICAL_MIRRORING);
			   }
			 */
		}
		// PRG Switching Area;
		MMC1_prgSwitchingArea = (value >> 2) & 1;
		// PRG Switching Size:
		MMC1_prgSwitchingSize = (value >> 3) & 1;
		// VROM Switching Size:
		MMC1_vromSwitchingSize = (value >> 4) & 1;
		break;
	case 1:
		// ROM selection:
		MMC1_romSelectionReg0 = (value >> 4) & 1;
		// Check whether the cart has VROM:
		if (numCHRROM > 0) {
			// Select VROM bank at 0x0000:
			if (MMC1_vromSwitchingSize == 0) {
				// Swap 8kB VROM:
				if (MMC1_romSelectionReg0 == 0) {
					MMC1_load8kVromBank(value & 0xf, 0x0000);
				} else {
					MMC1_load8kVromBank(
					        Floor(numCHRROM / 2) + (value & 0xf),
					        0x0000
					        );
				}
			} else {
				// Swap 4kB VROM:
				if (MMC1_romSelectionReg0 == 0) {
					MMC1_loadVromBank(value & 0xf, 0x0000);
				} else {
					MMC1_loadVromBank(
					        Floor(numCHRROM / 2) + (value & 0xf),
					        0x0000
					        );
				}
			}
		}
		break;
	case 2:
		// ROM selection:
		MMC1_romSelectionReg1 = (value >> 4) & 1;
		// Check whether the cart has VROM:
		if (numCHRROM > 0) {
			// Select VROM bank at 0x1000:
			if (MMC1_vromSwitchingSize == 1) {
				// Swap 4kB of VROM:
				if (MMC1_romSelectionReg1 == 0) {
					MMC1_loadVromBank(value & 0xf, 0x1000);
				} else {
					MMC1_loadVromBank(
					        Floor(numCHRROM / 2) + (value & 0xf),
					        0x1000
					        );
				}
			}
		}
		break;
	default:
		// Select ROM bank:
		// -------------------------
		tmp = value & 0xf;
		I64 bank;
		I64 baseBank = 0;
		if (numPRGROM >= 32) {
			// 1024 kB cart
			if (MMC1_vromSwitchingSize == 0) {
				if (MMC1_romSelectionReg0 == 1) {
					baseBank = 16;
				}
			} else {
				baseBank =
				        (MMC1_romSelectionReg0 | (MMC1_romSelectionReg1 << 1)) << 3;
			}
		} else if (numPRGROM >= 16) {
			// 512 kB cart
			if (MMC1_romSelectionReg0 == 1) {
				baseBank = 8;
			}
		}
		if (MMC1_prgSwitchingSize == 0) {
			// 32kB
			bank = baseBank + (value & 0xf);
			MMC1_load32kRomBank(bank, 0x8000);
		} else {
			// 16kB
			bank = baseBank * 2 + (value & 0xf);
			if (MMC1_prgSwitchingArea == 0) {
				MMC1_loadRomBank(bank, 0xc000);
			} else {
				MMC1_loadRomBank(bank, 0x8000);
			}
		}
	}
}

U0 MMC1_Write(U16 address, U8 value)
{
	// See what should be done with the written value:
	if ((value & 128) != 0) {
		// Reset buffering:
		MMC1_regBufferCounter = 0;
		MMC1_regBuffer = 0;
		// Reset register:
		if (MMC1_getRegNumber(address) == 0) {
			MMC1_prgSwitchingArea = 1;
			MMC1_prgSwitchingSize = 1;
		}
	} else {
		// Continue buffering:
		//regBuffer = (regBuffer & (0xFF-(1<<regBufferCounter))) | ((value & (1<<regBufferCounter))<<regBufferCounter);
		MMC1_regBuffer =
		        (MMC1_regBuffer & (0xff - (1 << MMC1_regBufferCounter))) |
		        ((value & 1) << MMC1_regBufferCounter);
		MMC1_regBufferCounter++;
		if (MMC1_regBufferCounter == 5) {
			// Use the buffered value:
			MMC1_setReg(MMC1_getRegNumber(address), MMC1_regBuffer);
			// Reset buffer:
			MMC1_regBuffer = 0;
			MMC1_regBufferCounter = 0;
		}
	}
}

U0 ColorDreams_Write(U16 address, U8 value)
{
    // Swap in the given PRG-ROM bank:
    I64 prgbank = ((value & 0xf) * 2) % numPRGROM;
	MemCpy(MMU.RAM+0x8000, cartridgebuffer+0x10+0x4000*(prgbank), 0x8000);
    if (numCHRROM > 0) {
      // Swap in the given VROM bank at 0x0000:
      I64 bank = ((value >> 4) * 2);
	  MemCpy(MMU.VRAM, cartridgebuffer+0x10+(0x4000*numPRGROM)+(0x1000*(bank)), 0x2000);
    }
}
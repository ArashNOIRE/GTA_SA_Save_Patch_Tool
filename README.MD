# GTA San Andreas Save Patch Tool

A lightweight, modular Lua-based tool for modifying GTA San Andreas save files across multiple platforms (PC, PS2, and Xbox).

This tool allows toggling censorship-related flags inside save files, fixes internal game checksums, and automatically re-signs Xbox digital signatures without needing external cryptographic applications.

---

## ⚙️ Features

- **Toggle Censorship State:** Switch between censored (C) and uncensored (UC) save states.
- **Auto-Detect:** Automatically read and toggle the current state using the `auto` mode.
- **Multi-Platform Core:** Unified engine that handles offset shifts dynamically.
- **Internal Checksum Recalculation:** Automatically recalculates the game's internal 32-bit checksum to prevent "Corrupted Save File" errors.
- **Automated Xbox Resigning:** Built-in cryptographic module that automatically calculates and overwrites the mandatory 20-byte original Xbox security header using `HMAC-SHA1` (eliminating the need for third-party tools like XSavSig).
- **Structure Validation:** Strict verification of version IDs and "BLOCK" headers to safe-guard against file corruption.

---

## 📦 Supported Versions

- **GTA San Andreas PC 1.0** (Retail / Hoodlum)
- **GTA San Andreas PS2 1.03** (Original Black Label / AO-rated version)
- **GTA San Andreas Original Xbox v1** (Original release - Fully Supported with auto-signing)

> ⚠️ **Incompatibility Warning:** Other versions (such as XBox Rev1 ,PC v1.1/v2.0, PS2 v2.01/3.00, HD Remasters, or the Definitive Edition) are NOT supported due to fundamental structural changes in their save formats and global variable allocations.

---

## 🚀 Usage

Run the main orchestration script via the terminal by passing the operational mode, input path, and output path:

```bash
lua app.lua [mode] [input_file] [output_file]
```

## Modes
- c    → Force censored state (Enable censorship / Lock Hot Coffee content)

- uc   → Force uncensored state (Disable censorship / Unlock Hot Coffee content)

- auto → Dynamically toggle the current state based on current file flags

## 🛠 Project Structure & Requirements
- Lua 5.1+ (or a compatible environment like LuaJIT)
- No external dependencies (Runs entirely on pure mathematical emulation)

## File Architecture
- app.lua — The primary controller file handling argument parsing, platform detection, block-offset management, and flag toggling.

- crypto.lua — A standalone mathematical cryptography module implementing pure Lua versions of bitwise fallbacks, SHA-1, and HMAC-SHA1 hashing algorithms.

**Note: Ensure ``crypto.lua`` resides in the exact same directory directory as ``app.lua`` so it can be resolved via require("crypto").**

## ⚠️ Warnings & Safety
1. Always backup your original save data before executing the tool.

2. This utility directly overrides raw binary contexts; incorrect parameters or modified headers can lead to data unreadability.

3. Use at your own risk.

## Acknowledgements
This project would not have been possible without the work of many members of the GTA modding and reverse-engineering community.

**Special thanks to:**

*gothi* — Research on the GTA San Andreas censorship flag and GTACensorRemover.

*GTA Modding Wiki contributors* — Comprehensive documentation of save structures, byte boundaries, and hashing guidelines.

*Junior_Djjr* — CLEO runtime implementation demonstrating scripts mapping to $GF_Censore_Flag.

*Sanny Builder Team* — Script disassembly/decompilation suites and symbol databases.

*OrionSR* — Detailed layout documentation of official global variable structures.

*XSavSig Developers / Database Maintainers* — For cataloging the Xbox SigKey registries which allowed bypassing external dependency pipelines.

## 📜 License
This project is provided as-is for educational, preservation, and modding research purposes.
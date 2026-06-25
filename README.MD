# GTA San Andreas Save Patch Tool

A lightweight Lua-based tool for modifying GTA San Andreas save files (PS2 / PC versions).

This tool allows toggling censorship-related flags inside save files and automatically fixes checksum after modifications.

---

## ⚙️ Features

- Toggle censored / uncensored save state
- Auto-detect current state
- Automatic checksum recalculation
- Version validation (prevents unsupported saves)
- Simple CLI interface

---

## 📦 Supported Versions

- GTA San Andreas PC 1.0 (Retail)
- GTA San Andreas PS2 1.03 (Original Black Label / AO-rated version)

- ⚠️ Xbox versions (Original release and Revision 1) are NOT tested and compatibility is unknown.
- ⚠️ Other PC and console versions (PS2 2.01, 3.00, and later releases) are not supported and are likely incompatible due to save format and script changes.

---

## 🚀 Usage

```bash
lua app.lua c/uc/auto input.b output.b
```

---

## Modes

- ```c``` → Force censored state
- ```uc``` → Force uncensored state
- ```auto``` → Automatically toggle current state

---

## ⚠️ Warnings

- Only use with supported versions listed above
- Always backup your original save before using this tool
- Incorrect usage may corrupt save files
- This tool directly modifies binary save data
- Use at your own risk

---

## 🧠 Technical Notes

- Save structure starts with "BLOCK" header
- Version ID is stored after the header (4 bytes)
- Censorship flag is located at a fixed offset inside the save
- Checksum is a 32-bit unsigned sum of all bytes except the last 4

---


## 🛠 Requirements

- Lua 5.1+ (or compatible interpreter)
- No external dependencies

---

# Acknowledgements

This project would not have been possible without the work of many members of the GTA modding and reverse-engineering community.

Special thanks to:

- gothi — Research on the GTA San Andreas censorship flag and GTACensorRemover.
- GTA Modding Wiki contributors — Documentation of save structure, version IDs, checksums, and many internal game systems.
- Junior_Djjr — CLEO implementation demonstrating the use of GF_Censore_Flag.
- Sanny Builder & SBL contributors — Script disassembly/decompilation tools and symbol database.
- OrionSR — Save format documentation, reverse-engineering resources and documentation of official global variable names.
- GTASnP — Save editing research and documentation of version differences and save glitches.
- Everyone in the GTA modding community who spent years documenting the internals of GTA San Andreas.

---

## 📜 License

* This project is provided as-is for educational and modding purposes.
Use at your own risk.

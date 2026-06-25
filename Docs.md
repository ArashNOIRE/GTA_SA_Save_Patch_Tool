# Reverse Engineering the GTA San Andreas Hot Coffee Save Flag

## Introduction

This project began with a simple question:

> How does GTA San Andreas store and enforce the Hot Coffee censorship state?

The original goal was not to create a save editor or patching utility. Instead, the objective was to understand how existing Hot Coffee-related tools worked and how the game itself handled censorship internally.

One of the first references used during this investigation was **GTACensorRemover** by **gothi**, which provided important clues regarding the existence of a censorship-related save flag.

What followed was a reverse engineering process involving save file analysis, checksum validation, SCM decompilation, and comparison against existing Hot Coffee modifications.

---

# Stage 1 – Learning the Save File Structure

Before modifying any data, it was necessary to understand the structure of GTA San Andreas save files.

The primary source used during this phase was the **GTA Modding Wiki**, which provided documentation for:

* Save file layout
* BLOCK save header
* Version identifiers
* Checksum calculation
* General save internals

The wiki revealed that all GTA San Andreas saves begin with:

```text
BLOCK
```

followed by a version identifier.

The documentation also explained that the final four bytes of the save contain a checksum used by the game to verify save integrity.

Without this information, identifying valid save structures and rebuilding modified saves would have been significantly more difficult.

---

# Stage 2 – Searching for the Censorship Flag

Community documentation suggested that a censorship-related flag existed inside the save file.

An offset commonly mentioned online was:

```text
0x00EE
```

However, examination of actual save files quickly revealed inconsistencies.

The values stored at this location did not behave as expected and did not appear to directly control Hot Coffee functionality.

This suggested that:

* The documentation was outdated.
* The offset referred to another save format.
* The information was incomplete or incorrect.

Further investigation was required.

---

# Stage 3 – Discovering the Real Offset

By comparing multiple saves and studying information from GTACensorRemover, attention shifted to a different location:

```text
0x1462
```

This offset consistently behaved like a boolean flag.

Observed values:

```text
00 = Uncensored
01 = Censored
```

After modifying the value and rebuilding the checksum, the resulting save remained loadable by the game.

This strongly suggested that the actual Hot Coffee save state was stored here.

---

# Stage 4 – Understanding the Checksum System

Any modification immediately revealed another obstacle.

GTA San Andreas verifies save integrity using a checksum stored at the end of the file.

According to GTA Modding Wiki documentation, the checksum is calculated as the sum of all preceding save bytes.

Testing confirmed this behavior.

The algorithm can be expressed as:

```text
Checksum =
Sum of bytes from 0x00000 to 0x317FB
(mod 2^32)
```

The resulting 32-bit value is stored in the final four bytes of the save file.

If the checksum is invalid, the game reports:

```text
Corrupted Save File
```

This discovery became the foundation of the save patching tool.

---

# Stage 5 – Creating a Save Patching Tool

After identifying both the censorship flag and checksum algorithm, a Lua-based utility was developed.

The tool performs:

* Save validation
* Version detection
* Censorship state toggling
* Automatic checksum recalculation
* Save rewriting

Supported versions:

* GTA San Andreas PC 1.0 Retail
* GTA San Andreas PS2 1.03 (Original AO-rated release)

The tool intentionally refuses unsupported save versions to minimize the risk of corruption.

---

# Stage 6 – Investigating Existing Hot Coffee Mods

At this point a new question emerged:

> How do runtime Hot Coffee mods enable the feature?

To answer this, a CLEO-based Hot Coffee modification created by **Junior-Djjr** was examined.

After updating Sanny Builder's opcode database and successfully decompiling the script, the core logic became visible.

The script contained:

```scm
Alloc($GF_Censore_Flag, 1219)
```

This revealed an important fact:

```text
GF_Censore_Flag
=
Global Variable 1219
```

The mod continuously forces:

```scm
$GF_Censore_Flag = 0
```

to enable Hot Coffee.

Or:

```scm
$GF_Censore_Flag = 1
```

to disable it.

This was the first direct evidence that Rockstar's scripting system exposed a dedicated censorship variable.

---

# Stage 7 – Decompiling the Original PS2 Script

The next step involved analyzing the original PlayStation 2 version of:

```text
main.scm
```

The decompiled script contained approximately:

```text
542,962 lines
```

Inside the girlfriend-related scripts, a variable appeared:

```scm
$iCensoredVersion
```

Investigation eventually revealed logic similar to:

```scm
if $iCensoredVersion == 1
then
    return
end
```

This prevented portions of the girlfriend minigame logic from executing when censorship was enabled.

The relationship between the save flag and Hot Coffee functionality was becoming increasingly clear.

---

# Stage 8 – The Sanny Builder Discovery

A major breakthrough occurred when comparing different Sanny Builder databases.

Using:

```text
GTA SA (v1.0 - SBL)
```

displayed the variable as:

```scm
$iCensoredVersion
```

However, opening the exact same PS2 SCM using:

```text
GTA SA PS2 v1.0
```

displayed:

```scm
$GF_Censore_Flag
```

instead.

This proved that both names referred to the same global variable.

In other words:

```text
Global Variable 1219
          =
GF_Censore_Flag
          =
iCensoredVersion
```

This connected:

* The original Rockstar script
* The PS2 SCM
* The CLEO Hot Coffee mod

to a single shared variable.

---

# Final Understanding

The investigation ultimately revealed the following chain:

```text
Save File
    ↓
Offset 0x1462
    ↓
Global Variable 1219
    ↓
GF_Censore_Flag
    ↓
GFSEX Script
    ↓
Hot Coffee Enabled / Disabled
```

When a save is loaded:

1. The value stored at offset `0x1462` is loaded into Global Variable `1219`.
2. This variable becomes available to the girlfriend scripts as `GF_Censore_Flag`.
3. The `GFSEX` script checks the variable before executing Hot Coffee-related gameplay.
4. If the value is `1`, the sequence is blocked.
5. If the value is `0`, the sequence is allowed to continue.

---

# Key Discoveries

* The commonly referenced offset `0x00EE` does not appear to control Hot Coffee state in the investigated versions.
* The actual censorship flag is located at save offset `0x1462`.
* GTA San Andreas uses a 32-bit checksum stored in the final four bytes of the save.
* `GF_Censore_Flag` corresponds to Global Variable `1219`.
* `GF_Censore_Flag` and `iCensoredVersion` are simply different names for the same variable.
* The censorship state stored in the save file directly influences the behavior of the `GFSEX` script.

---

# Credits

## gothi

Creator of **GTACensorRemover**.

The tool provided valuable clues regarding the existence and location of censorship-related save data and helped guide the initial investigation.

## Junior-Djjr

Creator of the CLEO Hot Coffee activation mod.

The mod provided direct evidence linking Hot Coffee functionality to Global Variable 1219 (`GF_Censore_Flag`).

## GTA Modding Wiki

Provided critical documentation regarding:

* Save file structure
* Version identifiers
* Checksum behavior
* General GTA San Andreas save internals

## Sanny Builder Team

Provided the tools, opcode databases, and decompilation environment necessary to analyze GTA San Andreas scripts and identify internal variables.

## GTA Modding Community

For preserving documentation, research, and reverse engineering knowledge related to GTA San Andreas over the past two decades.

---

# Conclusion

What began as an attempt to understand an old censorship-removal tool evolved into a complete investigation of how GTA San Andreas stores and enforces Hot Coffee censorship.

The project involved:

* Save file analysis
* Checksum reverse engineering
* Version identification
* CLEO script analysis
* SCM decompilation
* Cross-validation between multiple independent sources

The final result was a documented path connecting a single byte inside a save file to the original Rockstar script logic that enables or disables one of the most famous pieces of cut content in video game history.

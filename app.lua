-- Command-line arguments:
-- mode       = c / uc / auto
-- inputFile  = source save file
-- outputFile = patched save file
local mode = arg[1]
local inputFile = arg[2]
local outputFile = arg[3]

-- Validate user input before doing anything.
-- Exit immediately if arguments are missing or invalid.
if not inputFile or not outputFile or (mode ~= "c" and mode ~= "uc" and mode ~= "auto") then
    print([[
GTA SA Save Patch Tool

Usage:
  lua patch.lua c/uc/auto input.b output.b

Modes:
  c     -> force censored state
  uc    -> force uncensored state
  auto  -> toggle current state

Warnings:
  - Only tested on GTA San Andreas PC 1.0 (Retail) and PS2 1.03 (Original Black Label / AO-rated version)
  - Not tested on Xbox version (Original release and Revision 1)
  - Compatibility with other versions is not guaranteed and may result in save corruption
  - Always keep a backup of your original save
  - Wrong usage may corrupt save file
]])
    os.exit(1)
end

-- Load an entire save file into memory and return it as a byte array.
-- GTA SA save files are small enough that loading them all at once is fine.
local function loadFile(path)
    local f = io.open(path, "rb")
    if not f then error("Cannot open: " .. path) end
    local data = f:read("*all")
    f:close()
    if #data == 0 then error("Empty file") end
    return { data:byte(1, #data) }
end

-- Write a byte array back to disk.
-- Each table entry must contain a value between 0 and 255.
local function saveFile(path, bytes)
    if not bytes then
        error("bytes is nil")
    end

    local f = io.open(path, "wb")
    if not f then
        error("Cannot open file for writing: " .. path)
    end

    for i = 1, #bytes do
        local b = bytes[i]
        if not b then
            error("Nil byte at index " .. i)
        end
        f:write(string.char(b))
    end

    f:close()
end

-- GTA SA stores a 32-bit checksum at the end of the save.
-- The checksum is calculated by summing every byte before it.
local function calculateChecksum(bytes)
    local sum = 0
    for i = 1, 0x317FC do
        sum = (sum + bytes[i]) % 0x100000000
    end
    return sum
end

-- Recalculate the checksum and write it to the last four bytes
-- of the save file in little-endian format.
local function writeChecksum(bytes)
    local sum = calculateChecksum(bytes)

    bytes[0x317FD] = sum % 256
    bytes[0x317FE] = math.floor(sum / 256) % 256
    bytes[0x317FF] = math.floor(sum / 65536) % 256
    bytes[0x31800] = math.floor(sum / 16777216) % 256
end

-- Read the entire save file once.
-- All modifications are performed in memory before writing.
local bytes = loadFile(inputFile)

-- Every GTA SA save begins with the ASCII string "BLOCK".
-- Reject files that do not match this signature.
if string.char(bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]) ~= "BLOCK" then
    error("Invalid save file")
end

-- Read the Version ID stored in Block 0.
-- This is used to prevent patching unsupported game versions.
local versionId = string.format("%02X %02X %02X %02X",
    bytes[6], bytes[7], bytes[8], bytes[9]
)

-- Known Version IDs that are currently supported by this tool.
-- Other versions may use different save structures or may not contain the required Hot Coffee game code.
local SUPPORTED = {
    ["75 81 DA 35"] = "PC 1.0",
    ["4C DC 1D 64"] = "PS2 1.03"
}

if not SUPPORTED[versionId] then
    error("Unsupported version: " .. versionId)
end

-- Offsets used by this tool.
-- Lua arrays start at 1, therefore +1 is required.
local OFF_FLAG = 0x1462 + 1 --> Hotcoffee flag
local OFF_CS   = 0x317FC + 1 --> Checksum

-- Read current values before making any modifications.
-- These values are kept for logging purposes.
local flag = bytes[OFF_FLAG]
local cs   = bytes[OFF_CS]

print(string.format("Flag: %02X", flag))
print(string.format("CS: %02X", cs))

-- Auto mode flips the current state:
-- 00 -> censored
-- 01 -> uncensored
local target = mode
if mode == "auto" then
    target = (flag == 0x00) and "c" or "uc"
end

-- Track whether a modification was actually performed.
-- This prevents unnecessary file creation.
local changed = false

-- Apply requested patch.
-- Only patch when the save is not already in the desired state.
if target == "uc" and flag == 0x01 then
    bytes[OFF_FLAG] = 0x00
    bytes[OFF_CS] = (cs - 1) % 256
    changed = true

elseif target == "c" and flag == 0x00 then
    bytes[OFF_FLAG] = 0x01
    bytes[OFF_CS] = (cs + 1) % 256
    changed = true
end

-- Nothing changed, so there is no reason to create a new file.
if not changed then
    print("No patch needed")
    return
end

-- Rebuild checksum and write the modified save to disk.
writeChecksum(bytes)
saveFile(outputFile, bytes)

-- Show exactly what changed for debugging and verification.
print(string.format(
    "Offset 0x1462 (Hotcoffee flag) changed from 0x%02X to 0x%02X",
    flag,
    bytes[OFF_FLAG]
))
print(string.format(
    "Offset 0x317FC changed from 0x%02X to 0x%02X",
    cs,
    bytes[OFF_CS]
))
print("Done:", inputFile, "----->", outputFile)

-- TODO : Add better comments
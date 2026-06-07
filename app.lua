-- inputs
local mode = arg[1]
local inputFile = arg[2]
local outputFile = arg[3]

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

-- load file
local function loadFile(path)
    local f = io.open(path, "rb")
    if not f then error("Cannot open: " .. path) end
    local data = f:read("*all")
    f:close()
    if #data == 0 then error("Empty file") end
    return { data:byte(1, #data) }
end

-- save file
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

-- checksum
local function calculateChecksum(bytes)
    local sum = 0
    for i = 1, 0x317FC do
        sum = (sum + bytes[i]) % 0x100000000
    end
    return sum
end

local function writeChecksum(bytes)
    local sum = calculateChecksum(bytes)

    bytes[0x317FD] = sum % 256
    bytes[0x317FE] = math.floor(sum / 256) % 256
    bytes[0x317FF] = math.floor(sum / 65536) % 256
    bytes[0x31800] = math.floor(sum / 16777216) % 256
end

-- load once
local bytes = loadFile(inputFile)

-- validate
if string.char(bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]) ~= "BLOCK" then
    error("Invalid save file")
end

local versionId = string.format("%02X %02X %02X %02X",
    bytes[6], bytes[7], bytes[8], bytes[9]
)

local SUPPORTED = {
    ["75 81 DA 35"] = "PC 1.0",
    ["4C DC 1D 64"] = "PS2 1.03"
}

if not SUPPORTED[versionId] then
    error("Unsupported version: " .. versionId)
end

-- config
local OFF_FLAG = 0x1462 + 1
local OFF_CS   = 0x317FC + 1

local flag = bytes[OFF_FLAG]
local cs   = bytes[OFF_CS]

print(string.format("Flag: %02X", flag))
print(string.format("CS: %02X", cs))

-- decide target
local target = mode
if mode == "auto" then
    target = (flag == 0x00) and "c" or "uc"
end

local changed = false

-- patch logic
if target == "uc" and flag == 0x01 then
    bytes[OFF_FLAG] = 0x00
    bytes[OFF_CS] = (cs - 1) % 256
    changed = true

elseif target == "c" and flag == 0x00 then
    bytes[OFF_FLAG] = 0x01
    bytes[OFF_CS] = (cs + 1) % 256
    changed = true
end

-- single exit point
if not changed then
    print("No patch needed")
    return
end

-- write everything we need in a file
writeChecksum(bytes)
saveFile(outputFile, bytes)

-- print the result
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
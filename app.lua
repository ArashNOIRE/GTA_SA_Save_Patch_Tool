-- app.lua
-- Main orchestration tool for patching GTA San Andreas save files.
-- Supports PC 1.0, PS2 1.03, and automatically signs Original Xbox v1 saves.

-- Import the cryptographic module for Xbox HMAC-SHA1 signing
local crypto = require("crypto")

-- Capture command-line execution arguments
local mode, inputFile, outputFile = arg[1], arg[2], arg[3]

-- Validate terminal parameters and present instructions if requirements aren't met
if not inputFile or not outputFile or (mode ~= "c" and mode ~= "uc" and mode ~= "auto") then
    print("GTA SA Save Patch Tool (PC / PS2 / XBOX v1)\n\nUsage:\n  lua app.lua c/uc/auto input.b output.b")
    os.exit(1)
end

-- Reads an entire binary file into a 1-indexed Lua byte array table
local function loadFile(path)
    local f = io.open(path, "rb")
    if not f then error("Cannot open: " .. path) end
    local data = f:read("*all")
    f:close()
    return { data:byte(1, #data) }
end

-- Writes a 1-indexed Lua byte array table back to disk as a binary stream
local function saveFile(path, bytes)
    local f = io.open(path, "wb")
    if not f then error("Cannot open file for writing: " .. path) end
    for i = 1, #bytes do f:write(string.char(bytes[i])) end
    f:close()
end

-- Calculates the 32-bit unsigned checksum of the save payload data
local function calculateChecksum(bytes, config, baseOffset)
    local sum = 0
    -- Compute sum strictly over the configured block size, honoring the base offset
    for i = baseOffset + 1, baseOffset + config.csSize do
        sum = (sum + bytes[i]) % 0x100000000 -- Mimic 32-bit integer overflow wrapping
    end
    return sum
end

-- Overwrites the 4-byte little-endian checksum entry at the end of the save block
local function writeChecksum(bytes, config, baseOffset)
    local sum = calculateChecksum(bytes, config, baseOffset)
    local csIndex = baseOffset + config.csSize + 1
    
    -- Deconstruct the 32-bit summation value into 4 distinct little-endian bytes
    bytes[csIndex]     = sum % 256
    bytes[csIndex + 1] = math.floor(sum / 256) % 256
    bytes[csIndex + 2] = math.floor(sum / 65536) % 256
    bytes[csIndex + 3] = math.floor(sum / 16777216) % 256
end

-- Recalculates and signs the 20-byte Xbox dashboard integrity block
local function resignXboxSignature(bytes)
    -- Step 1: Extract the mutable game save data context (everything from byte 21 onwards)
    local dataBuffer = {}
    for i = 21, #bytes do 
        table.insert(dataBuffer, string.char(bytes[i])) 
    end
    local message = table.concat(dataBuffer)

    -- Step 2: Convert the unique GTA San Andreas Xbox Signature Key from Hex to Binary
    local hexKey = "E3455E30DB1AEDC5A5CC787CDE5DAACE"
    local keyBuffer = {}
    for i = 1, #hexKey, 2 do
        table.insert(keyBuffer, string.char(tonumber(hexKey:sub(i, i+1), 16)))
    end
    local key = table.concat(keyBuffer)

    -- Step 3: Run the extracted save contents through the HMAC-SHA1 core module
    local signature = crypto.hmac_sha1(key, message)

    -- Step 4: Write the newly calculated 20-byte token into the front of the save array
    for i = 1, 20 do
        bytes[i] = signature:byte(i)
    end
    print("🔒 Xbox 20-byte digital signature successfully recalculated!")
end

-- Execute processing sequence
local bytes = loadFile(inputFile)

-- 1. Scan for the structural "BLOCK" magic sequence to establish file alignment
local baseOffset = 0
if string.char(bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]) == "BLOCK" then
    baseOffset = 0 -- Standard alignment (PC/PS2)
elseif string.char(bytes[21], bytes[22], bytes[23], bytes[24], bytes[25]) == "BLOCK" then
    baseOffset = 20 -- Xbox signature alignment shift
else
    error("Invalid save file: 'BLOCK' magic number not found.")
end

-- 2. Extract the unique 4-byte Version Identification Signature
local versionId = string.format("%02X %02X %02X %02X",
    bytes[baseOffset + 6], bytes[baseOffset + 7], bytes[baseOffset + 8], bytes[baseOffset + 9]
)

-- 3. Match against the system offsets registry
local SUPPORTED_PLATFORMS = {
    ["0:75 81 DA 35"]  = { name = "PC 1.0",   flagOffset = 0x1452, csSize = 0x317FC },
    ["0:4C DC 1D 64"]  = { name = "PS2 1.03", flagOffset = 0x1462, csSize = 0x317FC },
    ["20:4C DC 1D 64"] = { name = "Xbox v1",  flagOffset = 0x148E, csSize = 0x317FC }
}

local configKey = baseOffset .. ":" .. versionId
local currentPlatform = SUPPORTED_PLATFORMS[configKey]

if not currentPlatform then
    error(string.format("Unsupported save or version. ID: %s", versionId))
end

print("Detected Platform: " .. currentPlatform.name)

-- Read the initial status of the censorship flag variable
local OFF_FLAG = currentPlatform.flagOffset + 1
local flag = bytes[OFF_FLAG]

-- 4. Apply State Toggle Constraints
local target = mode
if mode == "auto" then 
    target = (flag == 0x00) and "uc" or "c" 
end

local changed = false
if target == "uc" and flag == 0x00 then 
    bytes[OFF_FLAG] = 0x01 
    changed = true
elseif target == "c" and flag == 0x01 then 
    bytes[OFF_FLAG] = 0x00 
    changed = true 
end

-- Exit immediately if the file is already in the targeted configuration state
if not changed then
    print("Save is already in target state. No patch needed.")
    return
end

-- Fix the internal GTA standard 32-bit checksum
writeChecksum(bytes, currentPlatform, baseOffset)

-- If processing an Xbox layout structure, intercept and calculate the HMAC security wrapper
if baseOffset == 20 then
    resignXboxSignature(bytes)
end

-- Write modifications to disk
saveFile(outputFile, bytes)
print("Done -> " .. outputFile)
-- crypto.lua
-- Pure Lua implementation of SHA-1 and HMAC-SHA1 cryptographic functions.
-- This module operates without any external dependencies or compiled C libraries.

local M = {}

-- ----------------------------------------------------------------------------
-- Bitwise Operations Fallback
-- ----------------------------------------------------------------------------
-- Standard Lua 5.1 lacks built-in bitwise operators. 
-- We attempt to load the native 'bit' or 'bit32' library if available (e.g., in LuaJIT).
-- If not found, we emulate basic 'bxor' and 'band' using pure mathematical logic.
local bit = rawget(_G, "bit") or rawget(_G, "bit32")
if not bit then
    bit = {
        -- Emulate Bitwise XOR (Exclusive OR)
        bxor = function(a, b) 
            local r, m = 0, 1 
            while a > 0 or b > 0 do 
                local aa, bb = a % 2, b % 2 
                if aa ~= bb then r = r + m end 
                a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 
            end 
            return r 
        end,
        -- Emulate Bitwise AND
        band = function(a, b) 
            local r, m = 0, 1 
            while a > 0 and b > 0 do 
                local aa, bb = a % 2, b % 2 
                if aa == 1 and bb == 1 then r = r + m end 
                a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 
            end 
            return r 
        end
    }
end

-- ----------------------------------------------------------------------------
-- Pure Lua SHA-1 Hash Implementation
-- ----------------------------------------------------------------------------
-- Computes a 160-bit (20-byte) cryptographic hash from an input string.
local function sha1(msg)
    -- Helper: Left-rotate a 32-bit unsigned integer by 'c' bits
    local function leftrotate(x, c) 
        return (x * 2^c + math.floor(x / 2^(32-c))) % 4294967296 
    end
    
    -- Initialize SHA-1 internal hash state constants
    local h0, h1, h2, h3, h4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
    local bits = #msg * 8
    
    -- Step 1: Pre-processing (Padding the message)
    -- Append a single '1' bit (0x80 byte) to the message
    msg = msg .. string.char(0x80)
    
    -- Pad with zeros until the message length is congruent to 56 mod 64 bytes
    while (#msg + 8) % 64 ~= 0 do 
        msg = msg .. string.char(0) 
    end
    
    -- Append the original message length in bits as a 64-bit big-endian integer
    msg = msg .. string.char(
        0, 0, 0, 0, 
        math.floor(bits / 16777216) % 256, 
        math.floor(bits / 65536) % 256, 
        math.floor(bits / 256) % 256, 
        bits % 256
    )
    
    -- Step 2: Process the message in successive 512-bit (64-byte) chunks
    for i = 1, #msg, 64 do
        -- Break chunk into sixteen 32-bit big-endian words w[1..16]
        local w = {}
        for j = 1, 16 do
            local o = i + (j - 1) * 4
            w[j] = msg:byte(o) * 16777216 + msg:byte(o+1) * 65536 + msg:byte(o+2) * 256 + msg:byte(o+3)
        end
        
        -- Extend the sixteen 32-bit words into eighty 32-bit words
        for j = 17, 80 do
            w[j] = leftrotate(bit.bxor(w[j-3], w[j-8], w[j-14], w[j-16]), 1)
        end
        
        -- Initialize hash value variables for this chunk
        local a, b, c, d, e = h0, h1, h2, h3, h4
        
        -- Main compression loop: 80 operations divided into 4 rounds
        for j = 1, 80 do
            local f, k
            if j <= 20 then
                f = bit.band(b, c) + bit.band(bit.bxor(b, 4294967295), d)
                k = 0x5A827999
            elseif j <= 40 then
                f = bit.bxor(b, c, d)
                k = 0x6ED9EBA1
            elseif j <= 60 then
                f = bit.band(b, c) + bit.band(b, d) + bit.band(c, d)
                k = 0x8F1BBCDC
            else
                f = bit.bxor(b, c, d)
                k = 0xCA62C1D6
            end
            
            -- Mix values and rotate registers
            local temp = (leftrotate(a, 5) + f + e + k + w[j]) % 4294967296
            e, d, c, b, a = d, c, leftrotate(b, 30), a, temp
        end
        
        -- Add this chunk's hash state to the total accumulated result
        h0 = (h0 + a) % 4294967296
        h1 = (h1 + b) % 4294967296
        h2 = (h2 + c) % 4294967296
        h3 = (h3 + d) % 4294967296
        h4 = (h4 + e) % 4294967296
    end
    
    -- Serialize the final 5 hash registers into a 20-byte binary string
    return string.char(
        math.floor(h0 / 16777216) % 256, math.floor(h0 / 65536) % 256, math.floor(h0 / 256) % 256, h0 % 256,
        math.floor(h1 / 16777216) % 256, math.floor(h1 / 65536) % 256, math.floor(h1 / 256) % 256, h1 % 256,
        math.floor(h2 / 16777216) % 256, math.floor(h2 / 65536) % 256, math.floor(h2 / 256) % 256, h2 % 256,
        math.floor(h3 / 16777216) % 256, math.floor(h3 / 65536) % 256, math.floor(h3 / 256) % 256, h3 % 256,
        math.floor(h4 / 16777216) % 256, math.floor(h4 / 65536) % 256, math.floor(h4 / 256) % 256, h4 % 256
    )
end

-- ----------------------------------------------------------------------------
-- HMAC-SHA1 Keyed-Hashing Engine
-- ----------------------------------------------------------------------------
-- Computes an HMAC signature using a private key and a message context.
function M.hmac_sha1(key, message)
    -- Keys longer than the SHA-1 block size (64 bytes) must be hashed first
    if #key > 64 then 
        key = sha1(key) 
    end
    
    -- Keys shorter than 64 bytes are padded with zeros to the right
    while #key < 64 do 
        key = key .. string.char(0) 
    end
    
    -- Generate the inner (ipad) and outer (opad) padding keys via XOR operations
    local ipad, opad = "", ""
    for i = 1, 64 do
        local k = key:byte(i)
        ipad = ipad .. string.char(bit.bxor(k, 0x36)) -- Inner padding constant (0x36)
        opad = opad .. string.char(bit.bxor(k, 0x5C)) -- Outer padding constant (0x5C)
    end
    
    -- Two-pass hashing sequence: hash the inner padding combined with the message,
    -- then hash the outer padding combined with the result of the first hash.
    return sha1(opad .. sha1(ipad .. message))
end

return M
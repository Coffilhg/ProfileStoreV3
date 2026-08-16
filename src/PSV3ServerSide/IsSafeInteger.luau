--[[--
	This is a part of ProfileStoreV3
    ProfileStoreV3 <https://github.com/Coffilhg/ProfileStoreV3>
    Copyright © 2026 Coffilhg (Roblox UserId 517222346)
    
	Licensed under the Apache License, Version 2.0 (the "License");
    see LICENSE & NOTICE or <http://www.apache.org/licenses/LICENSE-2.0>

    ProfileStoreV3 Version: 0.0.0
	Stars are appreciated!
--]]--

-- Check whether a value is a Real Number
local function IsSafeNumber(n: any): boolean
	-- must be a number
	if type(n) ~= "number" then
		return false
	end

	-- NaN check (NaN is the only value not equal to itself)
	if n ~= n then
		return false
	end

	-- inf / -inf check
	if n == math.huge or n == -math.huge then
		return false
	end

	return true
end

-- Check whether a value is an Integer Number
local function IsSafeInteger(n: any): boolean
	return IsSafeNumber(n) and n % 1 == 0
end

return IsSafeInteger
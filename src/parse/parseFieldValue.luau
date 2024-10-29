--!strict


--> Modules -------------------------------------------------------------------------------------------
local Tailwind = require("./tailwind")
-------------------------------------------------------------------------------------------------------


--> Variables -----------------------------------------------------------------------------------------
local DefaultOperation = function(a: number, b: number) return a + b end

local Operations = {
    ["+"] = DefaultOperation,
    ["-"] = function(a: number, b: number) return a - b end,
    ["*"] = function(a: number, b: number) return a * b end,
    ["/"] = function(a: number, b: number) return a / b end,
    ["%"] = function(a: number, b: number) return a % b end,
    ["^"] = function(a: number, b: number) return a ^ b end,
}
-------------------------------------------------------------------------------------------------------


--> Functions -----------------------------------------------------------------------------------------
local function StringStrip(input: string)
    return input:match("^%s*(.-)%s*$") :: string
end

local function ParseMeasurement(input: string)
    local scale, offset = 0, 0

    for _, part in input:split(" ") do
        local sign = part:match("^[%+%-%*/%%%^]")
        if sign then part = part:sub(2) end

        local measurement: string? = part:match("px$") or (part :: any):match("%%$")
        part = part:gsub("[^0-9%.]", "")

        local partNum = tonumber(part) or 0

        if measurement == "px" then
            offset = (not sign and DefaultOperation or Operations[sign])(offset, partNum)

        -- We need to divide the percentage into a scale percentage.
        elseif measurement == "%" then
            scale = (not sign and DefaultOperation or Operations[sign])(scale, partNum / 100)

        -- Number has no explicitly defined measurement so it is interpretted as scale.
        else
            scale = (not sign and DefaultOperation or Operations[sign])(scale, partNum)
        end
    end

    return scale, offset
end

local function ParseTuple(fieldName: string, fieldValue: string)
    fieldValue = fieldValue:gsub(" +%+ *", " +")
    fieldValue = fieldValue:gsub(" +%- *", " -")
    fieldValue = fieldValue:gsub(" +%* *", " *")
    fieldValue = fieldValue:gsub(" +/ *", " /")
    fieldValue = fieldValue:gsub(" +%% *", " %%")
    fieldValue = fieldValue:gsub(" +%^ *", " ^")

    local matches, matchesLength = fieldValue:gmatch("[^,]+"), 0
    local stringified = ""

    for match in matches do
        matchesLength += 1
        local scale, offset = ParseMeasurement(StringStrip(match))
        stringified ..= fieldName == "AnchorPoint" and
            `{matchesLength ~= 1 and ", " or ""}{scale}` or
            `{matchesLength ~= 1 and ", " or ""}{scale}, {offset}`
    end

    if matchesLength == 2 then
        return fieldName == "AnchorPoint" and `Vector2.new({stringified})` or `UDim2.new({stringified})`

    elseif matchesLength == 3 then
        return `Vector3.new({stringified})`
    end

    return stringified
end
-------------------------------------------------------------------------------------------------------


return function(fieldName: string, fieldValue: string)
    -- Removes duplicate whitespaces from the string and removes trailing commas and semicolons.
    fieldValue = fieldValue:gsub(" +", " "):gsub("[,;]$", "")
    
    -- Variable.
    if fieldValue:match("^%$") then return `"{fieldValue}"` end

    -- Tuple.
    local tupleMatch: string? = fieldValue:match("^[ \n]*%((.-)%)")
    if tupleMatch then return ParseTuple(fieldName, tupleMatch) end

    -- Hex.
    local hexMatch: string? = fieldValue:match("^(#[^,]+)")
    if hexMatch then return `Color3.fromHex "{hexMatch}"` end

    -- String.
    local stringMatch: string? = fieldValue:match("^(\"[^,]+\")")
    if stringMatch then return `{stringMatch}` end

    -- Measurement.
    local measurementMatch: string? = fieldValue:match("^([0-9.]+.*)")
    if measurementMatch then
        local scale, offset = ParseMeasurement(measurementMatch)
        if fieldName == "TextSize" then return `{offset}` end
        return `UDim.new({scale}, {offset})`
    end

	-- Tailwind Color.
	local tailwindColorMatch: string? = fieldValue:match("^(tw:[^:]+:%d+)")
	if tailwindColorMatch then
		return Tailwind[tailwindColorMatch] or "Color3.new(0, 0, 0)"
	end

    return fieldValue
end
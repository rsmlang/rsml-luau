--!strict


--> Services ------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------


--> Modules -------------------------------------------------------------------------------------------
local fs = require("@lune/fs")

local Tokenize = require("../tokenize")
local Parse = require("../parse")
-------------------------------------------------------------------------------------------------------


--> Types ---------------------------------------------------------------------------------------------
type Parsed = Parse.Parsed
type ParsedRules =  Parse.ParsedRules
type ParsedDerives =  Parse.ParsedDerives
type ParsedOthers =  Parse.ParsedOthers
-------------------------------------------------------------------------------------------------------


--> Functions -----------------------------------------------------------------------------------------
local function Unindent(str: any)
    return str:gsub("        ", ""):gsub("^[ \n\t]+", ""):gsub("[ \n\t]+$", "")
end

local function TableStringify(tble: any)
    local stringified = "{"

    for ik, v in tble do
        stringified ..= `\n    ["{ik}"] = {v},`
    end

    return stringified .. "\n}"
end

local function TableMap<IK, V, O>(tble: { [IK]: V }, fn: (item: V, idxOrKey: IK, idx: number) -> O)
    local tbleLength = #tble
    local newTble = table.create(tbleLength)

    local idx = 1
    for idxOrKey, item in tble do
        newTble[idx] = fn(item, idxOrKey, idx)
        idx += 1
    end

    return newTble
end


local function TableIsEmpty(tble: { [any]: any })
	for _ in tble do return false end
	return true
end


local function CreateStyleRule(data: Parsed, selector: string, baseIdx: string | number, parent: string?)
	local styleRuleName = `{parent}_StyleRule_{baseIdx}`

    local variables, properties, rules, priority = data.Variables, data.Properties, data.Rules, data.Priority

    return Unindent(`\
        local {styleRuleName} = Instance.new("StyleRule")\
        {styleRuleName}.Name = "{styleRuleName}"{(
            priority and `\n{styleRuleName}.Priority = {priority}` or ""
		)}\
        {styleRuleName}.Selector = "{selector}"{(
        	not TableIsEmpty(properties) and `\n{styleRuleName}:SetProperties({TableStringify(properties)})` or ""
		)}{(
            table.concat(TableMap(variables, function(value, name)
				return `\n{styleRuleName}:SetAttribute("{name}", {value})`
			end))
		)}\
        {styleRuleName}.Parent = {parent or "StyleSheet"} \
\
        {table.concat(TableMap(rules, function(data, selector, idx)
            return CreateStyleRule(data, selector, `{baseIdx}_{idx}`, `{styleRuleName}`) :: any
        end), "\n\n")}\
    `)
end


local function AddStyleDerive(sheetName: string, derivedSheetName: string)
    local deriveName = `{derivedSheetName}_Derive`

    return Unindent(`\
        local {deriveName} = Instance.new("StyleDerive")\
        {deriveName}.StyleSheet = {derivedSheetName}\
        {deriveName}.Parent = {sheetName}\
    `)
end

local function ToModuleString(parsed: Parsed, outputTo: string, parent: string, sheetName: string): string
	local rules, derives, variables = parsed.Rules, parsed.Derives, parsed.Variables

    return Unindent(`\
        local {sheetName} = Instance.new("StyleSheet"){
            if sheetName ~= "StyleSheet" then `\n{sheetName}.Name = "{sheetName}"` else ""
        }{(
            table.concat(TableMap(variables, function(value, name)
				return `\n{sheetName}:SetAttribute("{name}", {value})`
			end))
		)}\
\
        {table.concat(TableMap(rules, function(data, selector, baseIdx)
			return CreateStyleRule(data, selector, baseIdx, sheetName)
		end), "\n\n")}{if not TableIsEmpty(derives) then "\n\n" .. table.concat(TableMap(derives, function(path, idx)
            local derivedSheetName = `DerivedStyleSheet_{idx}`

			return ToModuleString(
				Parse(
					Tokenize(path),
					path:gsub("/[^/]+$", "") or path
				),
				path:gsub("$%.luau", ".rsml") or `{path}`,
				sheetName,
				`DerivedStyleSheet_{idx}`
			) ..  "\n" .. AddStyleDerive(sheetName, derivedSheetName)
		end), "\n\n") else ""}\
\
        {sheetName}.Parent = {parent}\
    `)
end
-------------------------------------------------------------------------------------------------------

return function(parsed: Parsed, outputTo: string)
	fs.writeFile(outputTo, (`-- .rsml -> .luau file.\n\n{ToModuleString(parsed, outputTo, "script", "StyleSheet")}\n\nreturn StyleSheet`))
end
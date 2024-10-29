--!strict


--> Modules -------------------------------------------------------------------------------------------
local Tokenize = require("../tokenize")
local ParseFieldValue = require("./parseFieldValue")
-------------------------------------------------------------------------------------------------------


--> Types ---------------------------------------------------------------------------------------------
type Token = Tokenize.Token

type ParsedPassOne = { ["@priority"]: string?, [string]: string | ParsedPassOne }

export type ParsedRules = { [string]: Parsed }
export type ParsedDerives = { string }
export type ParsedOthers = { [string]: string }

export type Parsed = {
    Derives: ParsedDerives,
    Priority: string?,
    Variables: ParsedOthers,
    Properties: ParsedOthers,
    Rules: ParsedRules,
}
-------------------------------------------------------------------------------------------------------


--> Functions -----------------------------------------------------------------------------------------
local function TableMap<Item, Output>(input: { [number]: Item }, handlerFn: (item: Item, idx: number) -> Output)
    local inputLength = #input
    local output = table.create(inputLength)
    for idx = 1, inputLength do output[idx] = handlerFn(input[idx], idx) end
    return output
end

local function TableTraverseAndBuild(tble: { [any]: any }, path: { any })
    local curr: { [any]: any } = tble

    for _, item in path do
        local hasNext: { [any]: any } = curr[item]
        if not hasNext then
            local newCurr = {}
            curr[item] = newCurr
            curr = newCurr
        
        else
            curr = hasNext
        end
    end

    return curr
end

local function PassOne_ToTable(tokens: { Token })
    local currPath: { any }, currParent: { [string]: any }?, currFieldName: string? = {}, nil, nil

    local parsed: ParsedPassOne = {}

    for _,token in tokens do
        local kind, value = token.Kind, token.Value

        if
            kind == "TAG_SELECTOR" or kind == "PSEUDO_SELECTOR" or kind == "STATE_SELECTOR" or
            kind == "NAME_SELECTOR" or kind == "CLASS_SELECTOR"
        then
            table.insert(currPath, value:gsub("[ \n\t]*{$", "") :: string)
            currParent = TableTraverseAndBuild(parsed, currPath) :: { [string]: any }

        elseif kind == "VARIABLE_FIELD_DECLARATION" or kind == "PROPERTY_FIELD_DECLARATION" then
            currFieldName = value:gsub("[ \n\t]*=$", "")

        elseif kind == "VARIABLE_FIELD_VALUE" or kind == "PROPERTY_FIELD_VALUE" then
            if currFieldName == nil then continue end
            (currParent or parsed)[currFieldName] = ParseFieldValue(currFieldName, value)

        elseif kind == "PRIORITY_VALUE" then
            (currParent or parsed)["@priority"] = value:gsub("[^%d]", "")

        elseif kind == "DERIVE_VALUE" then
            (currParent or parsed)[value] = "@derive"


        elseif kind == "BRACKET_CLOSED" then
            table.remove(currPath)
            currParent = TableTraverseAndBuild(parsed, currPath) :: { [string]: any }
        end
    end

	return parsed
end
 

local function PassTwo_Separation(parsed: ParsedPassOne, basePath: string): Parsed
    local derives: ParsedDerives, priority: string?, variables: ParsedOthers, properties: ParsedOthers, rules: ParsedRules =
        {}, parsed["@priority"] :: string?, {}, {}, {}

    parsed["@priority"] = nil

    for key, value in parsed do
        if typeof(value) == "table" then rules[key] = PassTwo_Separation(value, basePath)
        elseif value == "@derive" then table.insert(derives, key)
        elseif key:match("^%$") then variables[key:gsub("^%$", "")] = value
        else properties[key] = value end
    end

    return {
        Derives = TableMap(derives, function(item)
            item = item:match("\"(.*)\"") or item
            return item:gsub("^%.", basePath)
        end),
        Priority = priority,
        Variables = variables,
        Properties = properties,
        Rules = rules
    }
end
-------------------------------------------------------------------------------------------------------


return function(tokens: { Token }, basePath: string)
    return PassTwo_Separation(PassOne_ToTable(tokens), basePath)
end


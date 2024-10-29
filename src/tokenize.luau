--!strict


--> Modules -------------------------------------------------------------------------------------------
local fs = require("@lune/fs")
-------------------------------------------------------------------------------------------------------


--> Types ---------------------------------------------------------------------------------------------
type TokenConfigItem = {
	Pattern: string,
	Kind: string,
	Next: TokenConfig?
}

type TokenConfig = { TokenConfigItem }

export type Token = {
	Kind: string,
	Value: string
}
-------------------------------------------------------------------------------------------------------


--> Variables -----------------------------------------------------------------------------------------
local TokenMultiPrefix = `^[ \n\t]*`
local TokenSinglePrefix = `^ *`

local StringTokenPattern = `\"[^ "]*\"`
local NumberTokenPattern = `%d*%.?%d+`

local CommentMultiToken: TokenConfigItem = {
	Pattern = `{TokenMultiPrefix}%-%-%[%[`,
	Kind = "COMMENT_MULTI_OPEN",
	Next = {{
		Pattern = `{TokenMultiPrefix}[^%]]+%]?[^%]]`,
		Kind = "COMMENT_MULTI_INSIDE",
		Next = {{
			Pattern = `{TokenMultiPrefix}%]%]`,
			Kind = "COMMENT_MULTI_CLOSED"
		}}
	}}
}

local CommentSingleToken: TokenConfigItem = {
	Pattern = `{TokenMultiPrefix}%-%-[^\n\t]*`,
	Kind = "COMMENT_SINGLE"
}

local Tokens: TokenConfig = {
	{	
		Pattern = `^([ \n\t]*[^\n\t]+)%-%-%[%[`,
		Kind = "DEFAULT",
		Next = { CommentMultiToken }
	},

	CommentMultiToken,

	{	
		Pattern = `^([ \n\t]*[^\n\t]+)%-%-`,
		Kind = "DEFAULT",
		Next = { CommentSingleToken }
	},

	CommentSingleToken,


	{
		Pattern = `{TokenMultiPrefix}%.[^ ,;\n\t]+[ \n\t]*\{`,
		Kind = "TAG_SELECTOR",
	},

	{
		Pattern = `{TokenMultiPrefix}::[^ ,;\n\t]+[ \n\t]*\{`,
		Kind = "PSEUDO_SELECTOR",
	},

	{
		Pattern = `{TokenMultiPrefix}:[^ ,;\n\t]+[ \n\t]*\{`,
		Kind = "STATE_SELECTOR",
	},

	{
		Pattern = `{TokenMultiPrefix}#[^ ,;\n\t]+[ \n\t]*\{`,
		Kind = "NAME_SELECTOR",
	},


	{
		Pattern = `{TokenMultiPrefix}%$[^ \n\t]+ *=`,
		Kind = "VARIABLE_FIELD_DECLARATION",
		Next = {{
			Pattern = `{TokenSinglePrefix}[^\n\t]+[;,]?`,
			Kind = "VARIABLE_FIELD_VALUE"
		}}
	},

	{
		Pattern = `{TokenMultiPrefix}[^ \n\t]+ *=`,
		Kind = "PROPERTY_FIELD_DECLARATION",
		Next = {{
			Pattern = `{TokenSinglePrefix}[^\n\t]+[;,]?`,
			Kind = "PROPERTY_FIELD_VALUE"
		}}
	},

	{
		Pattern = `{TokenMultiPrefix}@derive`,
		Kind = "DERIVE_DECLARATION",
		Next = {{
			Pattern = `{TokenSinglePrefix}{StringTokenPattern}[;,]?`,
			Kind = "DERIVE_VALUE"
		}}
	},

	{
		Pattern = `{TokenMultiPrefix}@priority`,
		Kind = "PRIORITY_DECLARATION",
		Next = {{
			Pattern = `{TokenSinglePrefix}{NumberTokenPattern}[;,]?`,
			Kind = "PRIORITY_VALUE"
		}}
	},

	{
		Pattern = `{TokenMultiPrefix}\}`,
		Kind = "BRACKET_CLOSED",
	},
}
-------------------------------------------------------------------------------------------------------


--> Functions -----------------------------------------------------------------------------------------
local function LStrip(str: string)
	return str:gsub("^[ \n\t]+", "")
end
-------------------------------------------------------------------------------------------------------

return function(path: string)
	local content = fs.readFile(path)

	local cursorIdx, contentLength = 0, #content
	local nextTokens: TokenConfig = Tokens

	local parsed: { Token } = {}

	while cursorIdx <= contentLength do
		local matchFound = false

		for _, tokConfig in nextTokens do
			local start, finish, capture = string.find(content, tokConfig.Pattern, cursorIdx)
			if start == nil then continue end
			finish = capture and start + #capture - 1 or finish

			cursorIdx = (finish :: number) + 1

            table.insert(parsed, {
                Kind = tokConfig.Kind,
                Value = LStrip(string.sub(content, start, finish)) :: string
            })

			nextTokens = tokConfig.Next or Tokens

			matchFound = true
			break
		end

		if not matchFound then
            local start, finish = string.find(content, " *[^ \n]+", cursorIdx)
            if not start then break end
            cursorIdx = (finish :: number) + 1

            table.insert(parsed, {
                Kind = "DEFAULT",
                Value = LStrip(string.sub(content, start :: number, finish)) :: string
            })
        end
	end

	return parsed
end
-- license = "GNU GPL, v2 or later",
-- Author = Helwor
-- Debug Functions working on Zero-K mod (at least) of Spring engine, telling all functions at which lines in which widgets were involved in the error
-- How to: name this file my_debug.lua in LuaUI/Widgets
-- in your widget declare local d = VFS.Include("LuaUI\\Widgets\\my_debug.lua")
-- at the last line of the widget call d.DebugWidget(widget)
-- and that's all
local localEnv = {} 


-- now registering only what we need from global before we change environment, aswell will quicken access

local Echo              = Spring.Echo


local t                 = type
local type              = type
local table             = table
local pairs             = pairs
local ipairs            = ipairs
local next              = next
local debug             = debug
local tostring          = tostring
local tonumber          = tonumber
local getfenv           = getfenv
local setfenv           = setfenv
local unpack            = unpack

local debug             = debug

local select            = select
local pcall             = pcall
local xpcall            = xpcall
local error             = error
local string            = string


local Spring = Spring

local GreyStr    = "\255\155\155\155"


VFS.Include("LuaUI/callins.lua")


setfenv(1,localEnv) -- setting from now on this env as its own global


function linesbreak(s)
        if s:sub(-1)~="\n" then s=s.."\n" end
        return s:gmatch("(.-)\n")
end

function string:matchOptDot(pbefore,p,pafter)
    local withdot = '%.'..p
    local match
    local new_match = self:match(pbefore..p..pafter,1)
    while new_match do
        match=new_match
        p=p..withdot
        new_match=self:match(pbefore..p..pafter,1)
    end
    return match
end
function string:purgecomment(commented) -- remove comment and inform if the EoL is in block comment
    local line
    if not commented then
        line = self:gsub('%-%-%[%[.-%-%-%]%]','') -- removing block comments first that are in the same line
        --Echo(num..':after removing same line block\n'..line)
        line = line:gsub('%-%-[^%[][^%[].*$','') -- then remove normal line comment to not get fooled
        --Echo(num..':after removing simple comment\n'..line)
        line,commented = line:gsub('%-%-%[%[(.-)$','') -- then detect start of multi line block comment and remove it
        --Echo(num..':after removing start of block\n'..line)
        commented = commented>0 -- end of line is in a block comment or not
    else
        local uncommented
        line,uncommented = self:gsub('^(.-)%-%-%]%]','') -- detect end of multi line block comment and remove it
        commented=uncommented==0
        if uncommented>0 then -- check what is after the block comment with recursion
            --Echo(num..':after end of block\n'..line)
            line,commented = line:purgecomment(false)
        else
            --Echo(num..':line is totally commented')
            line ='' 
        end
    end
    return line,commented
end


GetLocalsOf= function(level,search)

    local T = {}
    local i = 1
    while true do
        local name, value = debug.getlocal(level+1, i)
        if not name then break end
        if search then
            if search==value then return value,i end
        else
            T[name]=value
        end
        i = i + 1
    end
    return T
end
GetWidgetInfos =function() 
    local info = debug.getinfo
    local widget
    for i=1,13 do
        local info = getinfo(i)
        if info.name and info.name:match("LoadWidget") then
            local locals=GetLocalsOf(i)
            if locals.text and locals.widget and locals.filename then
                widget={
                    code=locals.text,               
                    handler=locals.self,
                    widget=locals.widget,
                    filename=locals.filename,
                    basename = locals.basename,
                    source=getinfo(i).source, -- actually it's a long src
                    [getinfo(i).source]=true,
                    name = locals.basename,
                    nicename = locals.widget.GetInfo and locals.widget:GetInfo().name or locals.basename -- if the chunk had error, we won't get the nice name
                }
                break
            end

        end
    end

    --- now registering funcs---
    -- adding current environment's function 
    local utilfuncs={}  
    local source=debug.getinfo(1).source    
    if source~=widget.source then
        utilfuncs[source]=true
        for k,v in pairs(getfenv(1)) do -- get global functions in here
            if t(v)=="function" then
                defined=debug.getinfo(v).linedefined
                utilfuncs[k]=defined
                utilfuncs[defined]=k
            end
        end
    end
    widget.utilfuncs=utilfuncs


    -- adding callins and main function by scanning the code
    local callins,mainfuncs={},{}
    local linecount=0
    local code = widget.code
    local word
    
    -- matching function to find a word or wordA.wordB.wordC... within a given pattern (pattern before, pattern with dot or not, pattern after, occurrences)


    local line = 'X.Y.Z = function('


    local codelines={}
    local commented
    for line in code:gmatch('[^\n]+') do
        linecount=linecount+1
        --if linecount>32 and linecount<37 then
        line,commented = line:purgecomment(commented)
        --Echo(linecount..':'..line)
        --end

        codelines[linecount]=line
        word = line:match("function%s-widget:".."([%a]+)",1)
        if word then
             callins[word]=linecount
             callins[linecount]=word
        else
            local word = 
                         line:matchOptDot('function%s-','[%a_]+',':([%a_]+)%(',1) or  -- syntax function A:b(
                         line:matchOptDot('function%s-(','[%a_]+',')%s-%(',1) or
                         line:matchOptDot('(','[%a_]+',')%s-=%s-%(-%s-function',1) -- syntax a = function( or a = (function( NOTE:the latter might not be a function everytime
            if word then
             mainfuncs[word]=linecount
             mainfuncs[linecount]=word
            end
        end
    end
    widget.codelines = codelines
    mainfuncs[widget.source]=widget.nicename
    widget.callins=callins
    widget.mainfuncs=mainfuncs

    return widget
end

function tracefunc(func) -- wrap function to add properly traced back error message
    ------ function info
    local info = debug.getinfo(func)
    local definedline = info.linedefined
    local funcsource = info.source  
    local name = wid.utilfuncs[funcsource] and wid.utilfuncs[definedline] or
                 wid.mainfuncs[funcsource] and wid.mainfuncs[definedline] or 
                 wid.mainfuncs[funcsource] and wid.callins[definedline]

    local funcfilename=funcsource:gsub('LuaUI[\\/]Widgets[\\/](.-)%.lua','%1')
    --Echo('tracing func',name,funcfilename)
    --
    local debugging=function(res)
        local report=""
        local debugfunc_line=debug.getinfo(1).linedefined
        local runfunc_line = debug.getinfo(2).linedefined
        if not res[2] then Echo('ERROR',funcsource,name,definedline) return error(debug.traceback) end
        if type(res[2])=="function" then
            res[2]="'function'"
        end
        local STR = "["..res[2]..'\n'--..traceback
        --Echo("\nError in widget "..wid.nicename)
        report=report..'\nError in '..(name or 'unknown')..' in widget '..(wid.nicename or wid.name or 'no name found')
        .."\n"..GreyStr
        for line in linesbreak(STR) do 
            if  not line:find(debugfunc_line)
            and not line:find(runfunc_line)
            and not line:find'C\]: in function.-pcall\''
            and not line:find'%(tail call%):?'
            and not line:find'stack traceback'
            and not line:find'cawidgets.lua'
            and not line:find'camain.lua'
            and not line:find'chili_old/'
               then
                local widname = line:match('string "LuaUI[\\/]Widgets[\\/](.-)%.lua"')
                local current_line = tonumber(line:match':(%d*):')
                local defined_line = tonumber(line:match':(%d*)>')
                local callin_name = wid.callins[defined_line]
                local func_name = wid.mainfuncs[defined_line] or wid.utilfuncs[defined_line]
                local inThis = func_name   and ": in function '"..func_name.."'"
                            or callin_name and ": in CallIn '"..callin_name.."'"
                if inThis then
                    report=report.."["..(widname or 'unknown widget').."]:"..current_line..inThis.."\n"..GreyStr
                else
                    line = line:gsub('string "LuaUI[\\/]Widgets[\\/](.-)%.lua"','%1') -- remove useless path
                    line = line:sub(2)
                    report=report..line.."\n"..GreyStr
                end

            end
        end
          report=report.."\n---"
        
        return error(Echo(report)) 
    end
    local runfunc=function(func,...)
        local args={...}
        local res = {xpcall( function() return func(unpack(args)) end, debug.traceback)}
        local succeed = res[1]
        if not wid then Echo("Widget stopped") return end
        if succeed then return select(2,unpack(res)) else debugging(res) end
        --
    end
    return function(...) return runfunc(func,...) end
end

function DebugWidget(widget)
    for k,v in pairs(widget) do 
        if t(v)=='function' and wid.callins[k] then widget[k] = tracefunc(v) end
    end
end










wid = GetWidgetInfos()

return localEnv


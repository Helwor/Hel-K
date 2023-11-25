function widget:GetInfo()

  return {
    name      = "Log Handler",
    desc      = "write logs for widgets",
    author    = "Helwor",
    date      = "Jan 2022",
    license   = "GNU GPL v2 or later",
    layer     = -10e38, -- in the first api to load -- handling window will come at first Update cycle
    enabled   = true,  --  
    handler   = true,
    api       = true,
  }
end
local Echo = Spring.Echo


local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")

local Chili
local Window

WG.LogHandler = {
    logs = {}
    ,Check = function(self,...)
        local args = {...}
        local widget = widget
        local dir,filename,ext,file
        if type(args[1])=='table' then
            widget = table.remove(args,1)
        end
        local function GetBaseName()
            for i=4, 12 do 
                local k,v = debug.getlocal(i,5)
                if k=='basename' then
                    return v
                end
            end
        end
        -- case the filename is entire in the next param
        if type(args[1])=='string' and args[1]:match('%\\[%w%d]+.+$') then

        end
        if not file then
            dir = args[1] or 'LuaUI\\Widgets\\'

            filename = args[2] or (widget and widget.whInfo and widget.whInfo.basename or GetBaseName() or self:Date() .. ':Log....'):sub(1,-5)
            ext = args[3] or '.LOG'
            file = dir .. filename .. ext
        end
        local f,err = io.open(file, "a")
        if not f then
            Echo("[LOG]: Cannot write log on " .. file .. ':',err )
            if self.logs[file] then
                self.logs[file]:Delete()
            end
            return

        end
        f:close()
        return self.logs[file],file,widget,filename
    end
    ,New = function(self,...)
        -- NOTE: if we are in any CallIn , we can get the basename via widget.whInfo.basename
        -- if call it from base widget code, basename will be debug.getlocal(6,5) if debug.getlocal is not ran from a function else first param need to be upped
        local obj,file,widget,filename = self:Check(...)
        local new = false
        if not obj then
            if not file then
                return false, false
            end
            new = true
            obj = self:Create(file,widget,filename)
            local fread = io.open(file, "r")
            local prefix = fread:read(0) and '\n' or ''
            local dashes = '------------------'
            fread:close()
            -- prefix = ''
            local f = io.open(file, "a")
            f:write(prefix .. dashes .. self:Date() .. dashes)
            f:close()
            -- if widget then
            --     if widget.Shutdown then
            --         local oriShutdown = widget.Shutdown
            --         widget.Shutdown = function()
            --             obj:Delete()
            --             return oriShutdown()
            --         end
            --     else
            --         widget.Shutdown = function()
            --             obj:Delete()
            --         end
            --     end
            -- end
        end
        
        return obj, new
    end
    ,Create = function(self,file,widget,filename)
        local obj = setmetatable(
            {
                count=0
                ,lastline=false
                ,file = file
                ,filename = filename
                ,widget = widget
                ,win = false
            },{
                __index = self
                ,__call = self.Write
            }
        )
        self.logs[file] = obj
        return obj

    end
    ,Treat = function(self,t)
        -- NOTE: using pairs or ipairs will miss the nil values, we need to use #
        for i=1,#t do
            local s = t[i]
            if type(s)=='table' then
                t[i] = '{'..table.toline(s,true,150)..'}'
            else
                s = tostring(s)
                if s=='' then
                    t[i] = '<empty string>'
                else
                    t[i] = s
                end
            end

        end
        return table.concat(t,',')
    end
    ,Write = function(self,...)
        local f = io.open(self.file, "a")
        
        if not f then
            Echo("[LOG]: Couldn't write log on " .. self.file .. '.')
            return
        end
        self.count = self.count+1
        local str = self:Treat({...})
        local textbox = self.textbox
        if str == self.lastline then
            local success = f:write('*')
            if success then
                if textbox then
                    textbox:AddToLastLine('*')

                end
            else
                Echo("Log couldn't write ",str)
            end
        else
            self.lastline = str
            local complete = '[' .. self.count .. '][' .. ('%3f'):format(os.clock()) .. ']: ' .. str
            local success = f:write('\n',complete)
            if success then
                if textbox then
                    textbox:AddLine(complete)
                    -- if textbox.text:len()>800 then
                    --     Echo('text is over 800')
                    --     local str = textbox.text:sub(-800):gsub('^[^\n\r]+[\n\r]','')
                    --     textbox:SetText(str)
                    -- end
                end

            else
                Echo("Log couldn't write ",str)
            end

        end
        f:close()
        return true
    end
    ,ToggleWin = function(self)
        if not self.win then
            self:CreateWin()
            return
        end
        if self.win.visible then
            self.win:Dispose()
        end
    end
    ,DestroyWin = function(self)

    end
    ,CreateWin = function(self)
        if not Chili then
            Echo('LOG HANDLER CANNOT CREATE WIN WITHOUT CHILI')
            return
        end
        if self.win and self.win.hidden then
            self.win:Show()
            return
        end
        if not WG.ScrollableTextBox then
            Echo('NO WG.ScrollableTextBox !')
            return
        end
        local selfLog = self
        local content, scroll = WG.ScrollableTextBox(true)
        scroll.verticalSmartScroll = true
        scroll.backgroundColor[4] = 0.5
        scroll.borderColor = {0,0,0,0}
        -- scroll.padding = {5,5,15,5}
        scroll.right = 20
        local button1 = Chili.Button:New{
            caption = 'x'
            ,OnClick = { function(self) self.parent:Dispose() end }
            -- ,x=5
            ,y=4
            ,height=20

            ,right=4
            -- ,left = 90
            -- ,bottom=5
            ,width = 20
            -- ,top = -25

        }


        self.textbox = content
        self.textbox.color = {0,0,0,0}
        self.textbox.bottom = 20
        self.textbox.font.size = 11
        self.textbox.AddToLastLine = function(self)
            self.text = self.text .. '*'
            local lines = self.lines
            local lastID = #lines
            local line = lines[lastID]
            line.text = line.text .. '*'
            line.pls = {}
            self:_GeneratePhysicalLines(lastID)

        end
        self.win = Window:New{
            name = 'winlog_' .. self.filename
            ,parent = Chili.Screen0
            ,caption = 'winLog ' .. self.filename

            ,width=300
            ,height = 300
            -- ,autosize=true
            ,OnDispose = {
                function (self)
                    selfLog.win = nil
                    selfLog.textbox = nil
                end
            }
            -- ,padding = {0,0,15,0}
            ,itemPadding = {0,0,15,0}
            ,padding = {0,0,0,0}
            ,children = {scroll,button1}

        }
        self.win.color[4] = 0.2


        local fread = io.open(self.file, "r")
        local str = fread:read('*a')
        if str:len()>15000 then
            str = str:sub(-15000):gsub('^[^\n\r]+[\n\r]','')
        end
        fread:close()
        content:SetText(str)

        if WG.MakeMinizable then
            WG.MakeMinizable(self.win)
        end
    end
    ,Delete = function(self)
        self('[LOG END]')
        local obj = self.logs[self.file]
        if obj and obj.win then
            obj.win:Dispose()
        end
        self.logs[self.file] = nil

    end
    ,Date = function()
        return '[' .. os.date("%c") .. ']'
    end
    ,Clear = function(self)
        -- any of those work
        return io.output(self.file) and io.output():close()
        -- return io.open(self.dir .. self.filename,'w'):close()
        -- return io.open(self.dir .. self.filename,'w+'):close()
    end

}
local Log
function widget:Update()
    Chili = WG.Chili
    Window = Chili.Window
    widgetHandler:RemoveWidgetCallIn('Update',widget)
end

function widget:Initialize()
    if WG.Chili then
        widgetHandler:RemoveWidgetCallIn('Update',widget)
        Chili = WG.Chili
        Window = Chili.Window
    end
    -- Log = WG.LogHandler:New(widget)
    
    -- -- Log:Clear()
    -- Log('test2','test4')
    -- Log('',{'G',a=1})

end

function widget:Shutdown()
    -- Log:Delete()
end

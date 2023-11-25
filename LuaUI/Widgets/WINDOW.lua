

function widget:GetInfo()
    return {
        name      = "WINDOW",
        desc      = "Handler for some premade windows",
        author    = "Helwor",
        date      = "April 2023",
        license   = "GNU GPL, v2",
        layer     = 1050, -- before Smart Builders
        enabled   = true,  --  loaded by default?
        handler   = true,
    }
end
local Echo                          = Spring.Echo

-- local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")
local C_HEIGHT = 15 -- cell height
local B_HEIGHT = 22 -- button height
local color_header = {1,1,0,1}

local WINDOW = {
    C_HEIGHT = C_HEIGHT,
    B_HEIGHT = B_HEIGHT,
    instances = {},
    Tree={
    },
    color_header = color_header,
    count = 0,
    id = 0,
}
setmetatable(WINDOW.Tree,{__index=WINDOW})

function WINDOW:New()
    local inst = setmetatable({},{__index=WINDOW})
    self.count = self.count + 1
    self.id = self.id + 1
    inst:Create()
    self.instances[inst.win] = inst
    return inst
end

function WINDOW:Delete(dispose)
    local win = self.win
    if not win then
        return
    end
    Echo('deleting window ' .. self.instances[win].win.name, win.name)
    WINDOW.count = WINDOW.count - 1
    self.win = nil
    self.instances[win] = nil
    if dispose and win.Dispose then
        win:Dispose()
    end
end

function WINDOW:Create(children, minize)
    local inst = self
    children = children or {}
    Echo('creating window #' .. self.id)
    -- self.stackPanel = WG.Chili.StackPanel:New{
    --     x=1,
    --     y=self.C_HEIGHT,
    --     minHeight = self.C_HEIGHT,
    --     height = #children*self.C_HEIGHT,
    --     right = 1,
        
    --     itemPadding = {1,1,1,1},
    --     itemMargin = {0,0,0,0},
    --     children = children,
    -- }
    self.closeButton = WG.Chili.Button:New{
        caption = 'Close',
        OnClick = { function(self) if inst and inst.Delete then inst:Delete(true) end end },
        --backgroundColor=color.sub_close_bg,
        --textColor=color.sub_close_fg,
        --classname = "navigation_button",
        
        x = '66%',
        bottom=4,
        width='30%',
        height=self.B_HEIGHT,
    }
    self.searchButton = WG.Chili.Button:New{
        caption = "button",
        OnClick = { function() Spring.SendCommands("chat","watsup") end },
        --backgroundColor=color.sub_close_bg,
        --textColor=color.sub_close_fg,
        --classname = "navigation_button",
        
        x = '33%',
        bottom=4,
        width='30%',
        height=self.B_HEIGHT,
    }
    self.scrollPanel = WG.Chili.ScrollPanel:New{
        x=5,
        y=15,
        right=5,
        bottom = self.C_HEIGHT*2,
        children = {
            WG.Chili.Label:New{
                caption = '- header -',
                textColor = self.color_header,
                align='leftr',
            },
            -- self.stackPanel,
        },
    }

    self.win = {
        x = 200,
        y = 200,
        width  = 400,
        height = 600,
        classname = "main_window_small_tall",
        parent = WG.Chili.Screen0,
        -- backgroundColor = color.sub_bg,
        caption = 'Win Hook #' .. self.count,
        name = 'Win_hook_id_' .. self.id, -- creating a window that have the same name and an existing one will result in an auto dispose
        minWidth = 250,
        minHeight = 400,
        height = 28,
        OnDispose = { 
            function(self) if inst and inst.Delete then inst:Delete(false) end end
        },
        children = {
            self.scrollPanel,
            
            
            --Categorization checkbox
            WG.Chili.Checkbox:New{
                caption = 'check me',
                tooltip = 'or not',
                OnClick = { function(self)  end },
                -- textColor=color.sub_fg,
                checked = false,
                
                x = 5,
                width = '30%',
                height= self.C_HEIGHT,
                bottom=4,
            },
            
            --Search button
            self.searchButton,
            
            --Close button
            self.closeButton,

        },
    }

    WG.Chili.Window:New(self.win)
    if WG.MakeMinizable then
        WG.MakeMinizable(self.win, minize == 'minize')
    end
end
--- Panel
function WINDOW:AddPanel()
    local y = 0
    for i, obj in ipairs(self.scrollPanel.children) do
        y = y + obj.height
    end

    
    
    local stackPanel = WG.Chili.StackPanel:New{
        x=1,
        y=y,
        minHeight = self.C_HEIGHT,
        height = 0,
        right = 1,
        autoresize = true,
        itemPadding = {1,1,1,1},
        itemMargin = {0,0,0,0},
        children = {},
    }


    self.scrollPanel:AddChild(stackPanel)
    self.win:Invalidate()
    return stackPanel
end
--- Tree
function WINDOW:AddPanel()
    local y = 0
    for i, obj in ipairs(self.scrollPanel.children) do
        y = y + obj.height
    end

    local tree = WG.Chili.TreeView:New{
        x=0, right=0,
        y=y, bottom=0,
        defaultExpanded = false,
    }

    self.scrollPanel:AddChild(tree)
    self.tree = tree
    self.win:Invalidate()
    return tree
end
---

function WINDOW.Tree:Make(obj,panel,level)
    if not obj then
        return
    end
    level = level or 0
    
    for i,v in ipairs(obj.children) do
        v.label = WG.Chili.Label:New({caption = ('\t'):rep(level) .. v.caption, align = 'left'})
        panel:Resize(nil, panel.height + self.C_HEIGHT)
        panel:AddChild(v.label)
        self:Make(v, panel, level + 1)
    end
end

--- Panel
-- function WINDOW.Tree:Add(tree)
--     Echo('ADD PANEL?')
--     local panel = self:AddPanel()
--     self:Make(tree,panel)
--     return panel
-- end
--- Tree
function WINDOW.Tree:Add(tree)
    local panel = self:AddPanel()
    self:Make(tree,panel)
    return panel
end


function WINDOW.Tree:New(tree)
    local inst = setmetatable(WINDOW:New(), {__index=WINDOW.Tree})
    if tree then
        inst:Add(tree)
    end
    return inst
end

function widget:Initialize()
    WG.WINDOW = WINDOW
end

function widget:ShutDown()
    for k,v in pairs(WINDOW.instances) do
        v:Delete(true)
    end
end
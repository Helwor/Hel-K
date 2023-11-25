function widget:GetInfo()

  return {
    name      = "Chili Addon",
    desc      = "Add some methods utilities to Chili",
    author    = "Helwor",
    date      = "Dec 2022",
    license   = "GNU GPL v2 or later",
    layer     = 1001, -- after Chili
    enabled   = true,  
    handler   = true,
    api       = true,
  }
end
local Echo = Spring.Echo
local oriControlNew -- we gonna modify the Initialization Object in Chili to be able to detect Initialise and add an 'OnLoad' method
local Log
local Chili
local Window
local TextBox
local TreeViewNode
local Trackbar
include("keysym.lua")
local ESCAPE = KEYSYMS.ESCAPE
local f = VFS.Include("LuaUI\\Widgets\\UtilsFunc.lua")



local dragSelProps = {
    -- NOTE: For the highlighting to stay we need to maintain state.focused=true and selectable=true
    -- we switch selcetable only at Mouse Down for the window to drag and switch it back right ater in the return by a function, which is hacky but didnt find a better workaround yet
    startDrag = false
    ,selectable = true
    ,OnMouseUp = {function(self)
        -- NOTE: OnMouseUp is different than MouseDown as it is triggered even if OnMouseDown has been eaten by the window dragging
        local windowMoved
        if self.startDrag then
            local parentWin = self.parent.parent
            windowMoved = parentWin.x ~= self.startDrag[1] or parentWin.y ~= self.startDrag[2]
            self.startDrag = false
        end
        if self.selStart and (windowMoved==false or self.selStart == self.selEnd and self.selStartY == self.selEndY) then
            -- if user single click outside of bound of the text without moving (windowMoved == false)
            -- or if user simple click on the text without moving
            -- or if user drag mouse then come back to where it started
            -- -> we consider (unlike Chili) there is no selection
            -- Echo('window didnt move or selection has no range, unselecting')
            self:Unselect()
        end
        self.mouseDown = false
        self.realSelection = self.selStart
        return 

    end}
    ,HitTest = function(self,x,y,...) -- switch tooltip and create fake selection to highlight some words
        self.state.focused = true
            -- we maintain the highlighting in any case
        if self.mouseDown then
            return self
        end
        if self.realSelection then
            return self
        end 
        return self
    end
    ,Unselect = function(self)
        self.selStart = nil
        self.selStartY = nil
        self.selEnd = nil
        self.selEndY = nil
        self:Invalidate()
    end

    ,MouseDown =  
        -- NOTE: since we change the window behaviour by switching on and off selectable when we want
        -- the OnMouseDown will not be processed when selectable is false, as it is eaten by the window who want to drag itself
        function(self,ctrlx,ctrly,button,...)
            local clientX,clientY = ctrlx+self.clientArea[1], ctrly + self.clientArea[2]
            self.tooltipPos = false
            self.state.focused = true
            local func = function()  end
            if self:_GetCursorByMousePos(clientX, clientY).outOfBounds then
                -- set back selectable to true immediately on the return to avoid selection getting shut down
                self.selectable = false
                local parentWin = self.parent.parent
                self.startDrag = {parentWin.x,parentWin.y}
                func = function() self.selectable = true  end
                -- provoke a dragging
            else
                self.mouseDown = button
            end
            return TextBox.MouseDown(self,ctrlx,ctrly,button,...), func()

        end

}


local TTProps = {
    lastx = -1
    ,lasty = -1
    ,tooltip = ''
    ,fakeSel = false
    ,OnMouseUp = {
        function(self,x,y,...)
            self.lastx, self.lasty = -1, -1 -- provoke a refresh
            -- self.fakeSel = false
        end
    }
    ,HitTest = function(self,x,y,...)
        ----- Fake Selecting
        self.state.focused = true
        if self.selStart and not self.fakeSel then
            return self
        end
        if self.lastx==x and self.lasty==y then
            return self
        end
        self.lastx,self.lasty = x,y

        local infos = self:_GetCursorByMousePos(x, y)
        if infos.outOfBounds then
            self.tooltip = ''
            if self.selStart then
                self:Unselect()
            end
            return self
        end
        local lineID = infos.cursorY
        local logLine = self.lines[lineID]
        local word,pos,endPos = logLine.text:word(infos.cursor)
        local tooltip, textPos
        if word then
            tooltip = self.tooltipWords[word]
            if tooltip then
                textPos = tooltip and (lineID .. '-' ..  pos)
            end
        end
        if textPos then
            if self.tooltipPos~=textPos then
                self.selectable = true
                self.state.focused = true
                self.fakeSel = true
                self:_SetSelection(pos, lineID, endPos+1, lineID)
                self:Invalidate()
            end
        elseif self.selStart then
            self:Unselect()
        end
        self.tooltip = tooltip
        self.tooltipPos = textPos
        ----
        return self
    end
    ,OnMouseDown = {
        function(self)
            self.tooltipPos = false
            self.mouseDown = true
            self.fakeSel = false
        end
    }
    ,OnMouseOut = {
        function(self)
            if self.selStart and self.fakeSel then
                self:Unselect()
                -- the tooltip will be removed on mouse out but not our tooltipPos
            end
        end
    }
    ,Unselect = function(self)
        self.selStart = nil
        self.selStartY = nil
        self.selEnd = nil
        self.selEndY = nil
        self.tooltipPos = false
        self:Invalidate()
    end

}

local function ScrollableTextBox(withDragSelectable,tooltipWords)

    
    local content = Chili.TextBox:New{
        x = 5
        ,y = 5
        ,right = 0
        ,align = "left"
        ,valign = "left"
        ,fontsize = 12
        ,multiline = true
        ,OnParentPost = {function(self) self.font.autoOutlineColor = false end}
        --user defined keys
    }
    
    local scroll = Chili.ScrollPanel:New{
        x = 5
        ,y = 20
        ,right = 25
        -- ,top = 12
        ,align = "left"
        ,valign = "left"
        ,fontsize = 12
        ,bottom =16
        -- workaround to trigger the text updating on scroll, but there's probably a more decent way to do it
        ,Update = function(self,...)
            self.children[1]:Invalidate()
            self.inherited.Update(self,...)
        end

        ,children = {content}
    }
    if withDragSelectable then
        for k,v in pairs(dragSelProps) do
            content[k] = v
        end
    end
    if tooltipWords then
        content.tooltipWords = tooltipWords

        for k,v in pairs(TTProps) do
            if type(v)=='table' and type(content[k])=='table' then
                table.insert(content[k],v[1])
            else
                if k == 'HitTest' then
                    local func
                    if content.HitTest then
                        -- Echo('it got hit test')
                        local oriFunc = content.HitTest
                        func = function(self,x,y,...)
                            oriFunc(self,x,y,...)
                            return v(self,x,y,...)
                        end
                    else
                        func = v
                        -- Echo('no other hit test')
                    end
                end
                content[k] = v
            end

        end
    end
    return content, scroll
end





local function MakeMinizable(obj,minize,minizedHeight)
    local isLoaded = type(obj) == 'userdata' or getmetatable(obj) and obj._hlinks
    if not isLoaded then
        Echo('NOT MINIZING A TABLE',obj.name or obj.classname or 'unknown object')
        return obj
    end
    if isLoaded and obj.SwitchMinize then
        if minize then
            obj:SwitchMinize(true)
        end
        return
    end
    minizedHeight = minizedHeight or 28
    local minW, maxW = 50,250
    local minizedWidth = 50
    local padding = obj.padding or {10,10,10,10}
    local title = obj.caption or obj.name or '          '

    -- WARN: trying to make a font from obj.font when obj.noFont is true (because no caption) provoke an INFINITE LOOP
    local font, tmpFont = not obj.noFont and obj.font or {}
    local GetTextWidth = font.GetTextWidth
    if obj.noFont then
        obj.noFont = false
        obj.font = Chili.Font:New(font)
    end

    --[[if obj.noFont then
        -- 
        Echo('HAS NO FONT')
    else--]]if not obj.font.GetTextWidth then
        local _font = Chili.Font:New(font)
        minizedWidth = math.max(padding[1],10) + _font:GetTextWidth(title) + math.max(padding[3],10)
        _font:Dispose()
    else
        -- Echo('GOT GET TEXT WIDTH')
        minizedWidth = math.max(padding[1],10) + obj.font:GetTextWidth(title) + math.max(padding[3],10)
    end
    minizedWidth = math.min( math.max(minizedWidth, minW), maxW )

    local props = {
        tlcX = false,
        tlcY = false,
        mouseDown = false,

        minizedHeight = minizedHeight,
        minizedWidth = minizedWidth < obj.width and minizedWidth or width,
        minWidthNormal = obj.minWidth,
        minHeightNormal = obj.minHeight>minizedHeight + 10 and obj.minHeight or minizedHeight + 10,
        resizableNormal = obj.resizable,
        backupW = obj.width,
        backupH = obj.height>minizedHeight + 10 and obj.height or minizedHeight + 10,
        noshow = {},
        nocaption = not obj.caption,


        ---- not using OnMouseDown as it is getting eaten by the padding
        ---- instead using the real MouseDown 
        -- OnMouseDown = {
        --     function(self,clientx,clienty,button,...)
        --         -- self.backupW, self.backupH = self.width, self.height
        --         local mx,my = false, false
        --         if button==1 and clienty+self.clientArea[2] < self.minizedHeight then
        --             mx, my = Spring.GetMouseState()
        --         end
        --         self.tlcX,self.tlcY = mx, my
        --         self.mouseDown = button
        --     end
        -- },
        MouseDown = function(self,winx,winy,button,...)
            -- self.backupW, self.backupH = self.width, self.height
            local mx,my = false, false
            if button==1 and winy < self.minizedHeight then
                mx, my = Spring.GetMouseState()
            end
            self.tlcX,self.tlcY = mx, my
            self.mouseDown = button
            if not self.class then
                if self.FindClass then
                    self.class = self:FindClass()
                else
                    self.class = Chili.Window
                end
            end
            return Window.MouseDown(self,winx,winy,button,...)
        end,
        OnMouseUp = {
            function(self,clientx,clienty,button,...)
            if not self.mouseDown then
                return true
            end
            self.mouseDown = false
            local switchMinize = false
            if self.tlcX then
                local mx,my = false, false
                if button==1 and clienty+self.clientArea[2] < self.minizedHeight then
                    mx,my = Spring.GetMouseState()
                    if math.abs(mx-self.tlcX) <3 and math.abs(my-self.tlcY)<3 then
                        switchMinize = true
                    end
                end
                self.tlcX,self.tlcY = mx, my
            end
            if switchMinize then
                self:SwitchMinize()
                return true
            end
            if self.height~=self.minizedHeight then
                self.backupW,self.backupH = self.width, self.height
            end
        end
        }
        -- ,tries = 0
        ,SwitchMinize = function(self,bool)
            if bool==nil then
                bool = not self.minized
            end
            if self.minized == bool then
                -- Log(self.name,'minize is already',bool)
                return
            end
            self.minized = bool
            if bool then

                self.resizable = true
                self.minWidth = self.minizedWidth
                self.minHeight = self.minizedHeight
                self:Resize(self.minizedWidth,self.minizedHeight)
                self.resizable = false
                local tries = 0
                for child, i in pairs(self.children_hidden) do
                    self.noshow[child]  = true
                end
                while self.children[1] do
                    if tries>800 then
                        Echo('infinite loop in Switch Minize')
                        -- Log('infinite loop in Switch Minize')
                        break
                    end
                    self.children[1]:Hide()
                    tries = tries + 1
                end
                if self.nocaption then
                    self.caption = title
                    self:Invalidate()
                end

            else
                self.resizable = true
                self.minWidth = self.minWidthNormal
                self.minHeight = self.minHeightNormal
                self:Resize(self.backupW,self.backupH)
                self.resizable = self.resizableNormal
                for child, i in pairs(self.children_hidden) do
                    if self.noshow[child] then
                        self.noshow[child] = nil
                    else
                        child:Show()
                    end
                end
                if self.nocaption then
                    self.caption = nil
                end
            end
        end,
        OnResize = {
            function(self,clientWidth,clientHeight,a,b)
                if self.height == self.minizedHeight  then
                    self:SwitchMinize(true)
                    if self.mouseDown==1 then
                        self:MouseUp(0,0,1)
                        return true
                    end
                end
            end
        },
    }

    for k,v in pairs(props) do
        if type(v)=='table' and obj[k] then
            table.insert(obj[k],1,v[1])
        else
            obj[k] = v
        end
    end
    -- Echo("minizedHeight is ", props.minizedHeight)
    -- Echo("minizedWidth is ", props.minizedWidth)
    -- Echo("minWidthNormal is ", props.minWidthNormal)
    -- Echo("minHeightNormal is ", props.minHeightNormal)
    -- Echo("resizableNormal is ", props.resizableNormal)
    -- Echo("backupW is ", props.backupW)
    -- Echo("backupH is ", props.backupH)
    if obj.height == obj.minizedHeight or minize then
        obj:SwitchMinize(true)
    end
end

-- local function NodeSetText(self,text)
--     self.children[1]:SetText(text)
-- end

local function AddTrackbarFunctions()
    local Echo = Spring.Echo
    local table, type, math, ipairs, pairs = table, type, math, ipairs, pairs
    local debug = debug
    local floor = math.floor
    local strFormat = string.format

    setfenv(1,Chili)
    local chilienv = getfenv()
    local MakeWeakLink, IsObject, CompareLinks, UnlinkSafe = MakeWeakLink, IsObject, CompareLinks, UnlinkSafe


    local function FormatNum(num, precFormat,step)
      if precFormat then
        return strFormat(precFormat, num)
      elseif (num == 0) then
        return "0"
      else
        if step<1 then
            local dec =tostring(step):match('%.(.+)')
            dec = dec:len()
            return strFormat("%." .. dec .."f", num)
        end
        local absNum = math.abs(num)
        if (absNum < 0.01) then
          return strFormat("%.3f", num)
        elseif (absNum < 1) then
          return strFormat("%.2f", num)
        elseif (absNum < 10) then
          return strFormat("%.1f", num)
        else
          return strFormat("%.0f", num)
        end
      end
    end

    function Trackbar:SetValue(v)

      local steps = floor((v / self.step) + 0.5)
      v = steps * self.step

      v = self:_Clamp(v)
      local oldvalue = self.value
      self.value = v
      if self.tooltipFunction then
        self.tooltip = self.tooltipFunction(self, v)
      elseif self.useValueTooltip then
        self.tooltip = FormatNum(v, self.tooltip_format, self.step)
      end
      self:CallListeners(self.OnChange,v,oldvalue)
      self:Invalidate()
    end


    -- function Trackbar:SetValue(v)

    --   local steps = floor((v / self.step) + 0.5)
    --   v = steps * self.step

    --   v = self:_Clamp(v)
    --   local oldvalue = self.value
    --   self.value = v
    --   if self.tooltipFunction then
    --     self.tooltip = self.tooltipFunction(self, v)
    --   elseif self.useValueTooltip then
    --     self.tooltip = FormatNum(v, self.tooltip_format)
    --   end
    --   self:CallListeners(self.OnChange,v,oldvalue)
    --   self:Invalidate()
    -- end



    local i, name, item = 0, true
    while name do
        i = i + 1
        name, item = debug.getupvalue(Trackbar.SetValue,i)
        if name == 'FormatNum' then
            debug.setupvalue(Trackbar.SetValue, i, FormatNum )
            break
        end
    end

end



local function AddNodeFunctions()
    local Echo = Spring.Echo
    local table, type, math, ipairs, pairs = table, type, math, ipairs, pairs
    setfenv(1,Chili)
    local MakeWeakLink, IsObject, CompareLinks, UnlinkSafe = MakeWeakLink, IsObject, CompareLinks, UnlinkSafe
    setfenv(1,Chili.TreeViewNode)

    TreeViewNode.preserveChildrenOrder = true


    function TreeViewNode:SetText(text)
        local child = self.children[1]
        if child and child.SetText then
            child:SetText(text)
            self.caption = text
            return true
        end
    end

    function TreeViewNode:visibleparent()
        local parent = self.parent
        while parent and not parent.expanded do
            parent = parent.parent
        end
        return parent
    end



    function TreeViewNode:pos()
        local n = self.parent.nodes
        for i=1,#n do
            if CompareLinks(self,n[i]) then
                return i, false
            end
        end
        local n = self._nodes_hidden
        for i=1,#n do
            if CompareLinks(self,n[i]) then
                return i, true
            end
        end
    end

    function TreeViewNode:tail()
        local count = #self.nodes
        local newtail,tail = self.nodes[count], self
        while newtail do
            tail = newtail
            local len = #tail.nodes
            newtail = tail.nodes[len]
            count = count + len
        end
        return tail, count
    end

    function TreeViewNode:childpos()
        local n = self.parent.children
        for i=1,#n do
            if CompareLinks(self,n[i]) then
                return i, false
            end
        end
    end



    function TreeViewNode:MoveTo(toNode)
        self.parent:RemoveChild(self)
        toNode:AddChild(self)
        self.treeview = toNode.treeview
    end


    function TreeViewNode:BelongToBranch(target)
        local nodes = self.nodes
        if CompareLinks(self,target) then
            return true
        end
        for i=1,#nodes do
            -- Echo('verif node',self.caption,nodes[i].caption)
            if CompareLinks(target,nodes[i]) then
                return true
            end
            if nodes[i]:BelongToBranch(target) then
                return true
            end
        end
        local nodes = self._nodes_hidden
        for i=1,#nodes do
            if CompareLinks(target,nodes[i]) then
                return true
            end
            if nodes[i]:BelongToBranch(target) then
                return true
            end
        end
        return false
    end



    function TreeViewNode:Insert(nodeAfter)
        -- FIX: there should be an option to remap children order when removing as it is done only when adding
        if self:BelongToBranch(nodeAfter) then
            Echo('Chili Warning, trying to insert node',self.name, self.caption, 'behind', nodeAfter.name,nodeAfter.caption,' You cannot insert your branch into the same')
            return
        end
        -- local pos,hidden = nodeAfter:pos()
        local parent = nodeAfter.parent
        local nodepos = nodeAfter:pos()
        local childPos = parent.children[UnlinkSafe(nodeAfter)] -- fixed now!//not reliable, the children table is not remapped after a remove (with or without preserveChildrenOrder == true)

        -- local childPos = nodeAfter:childpos()

        -- Echo('child pos of nodeAfter?',childPos)
        -- Echo('node pos of nodeAfter?',nodepos)
        -- Echo('inserting...')
        -- Echo('removing node',nodeAfter.name,nodeAfter.caption,'from',parent.name,parent.caption)
        -- Echo("parent.preserveChildrenOrder is ", parent.preserveChildrenOrder)
        local realPreserve = parent.preserveChildrenOrder
        parent.preserveChildrenOrder = true
        parent:RemoveChild(nodeAfter)
        parent.preserveChildrenOrder = realPreserve
        -- local nowAtPos = parent.children[childPos]
        -- Echo('--->Now At child Pos' .. childPos ..':', nowAtPos.caption,nowAtPos.name,'verif',parent.children[UnlinkSafe(nowAtPos)],UnlinkSafe(nowAtPos).name)
        -- Echo('removing self',self.name,self.caption,'from',self.parent.name,self.parent.caption)
        if self.parent then
            self.parent:RemoveChild(self)
        end
        -- Echo('add node',self.name,self.caption,'to ',parent.name,parent.caption,'at node pos',nodepos,'at child pos',childPos)
        parent:AddChild(self, true, nodepos, childPos)
        self.treeview = parent.treeview
        -- Echo('putting back removed on tail',tail.name,tail.caption)
        local tail = self:tail()
        tail:AddChild(nodeAfter)
        nodeAfter.treeview = tail.treeview

    end



    function TreeViewNode:RemoveChild(obj)
        local children = self.children
        local pos = children[UnlinkSafe(obj)]
        local remap = pos and children[pos+1]

        local result = inherited.RemoveChild(self,obj)


        local nodes = self.nodes

        for i=1,#nodes do
            if CompareLinks(nodes[i],obj) then
                table.remove(nodes, i)
                break
            end
        end
        if self.preserveChildrenOrder then
            if remap and result then
                for obj,i in pairs(children) do
                    if type(i) == "number" and i >= pos then
                        children[obj] = i - 1
                    end
                end
            end
        end
      return result
    end

    function TreeViewNode:Extract(obj)
        -- Echo("obj is ", obj and obj.caption)
        obj = obj or self
        local parent = obj.parent

        local branch = obj.nodes[1]
        if branch then
            local pos = obj:pos()
            obj:RemoveChild(branch)
            local extracted = parent:RemoveChild(obj)
            parent:AddChild(branch, true, pos)
            branch.treeview = parent.treeview
            return extracted and obj
        end
        return parent:RemoveChild(obj) and obj
        -- Echo("nextNode is ",nextNode and nextNode.caption)
        -- if not nextNode then
        --     return parent:RemoveChild(obj)
        -- end
        -- nextNode.parent:RemoveChild(nextNode)
        -- parent:AddChild(nextNode)
        -- return extracted

    end


    function TreeViewNode:AddChild(obj, isNode, index, childPos)
        -- index = index or #self.children+1
        if (isNode~=false) then
            local node_index
            if index then
                node_index = math.min(#self.nodes + 1, index)
                local atPos = self.nodes[node_index]
                -- Echo("atPos is ", atPos)
                if atPos then
                    index = childPos or self.children[UnlinkSafe(atPos)]-- unreliable// fixed now
                    -- index = childPos or atPos:childpos()
                    -- Echo('atPos=>>',index)
                else
                    index = false
                end
            else
                node_index = #self.nodes + 1
            end
            -- Echo('node index??',node_index, 'child index??',index)
            if childPos then
                -- node_index = 2
            end
            -- self.nodes[#self.nodes+1] = MakeWeakLink(obj) -- old
            table.insert(self.nodes, node_index, MakeWeakLink(obj))
        end
        if self.parent and self.parent.RequestRealign then self.parent:RequestRealign() end
        -- -- visual debug
        -- local ret = inherited.AddChild(self,obj,false, index)
        -- if isNode~=false then
        --     local pos = 0
        --     for i=1,#self.nodes do
        --         if CompareLinks(self.nodes[i], obj) then
        --             pos = i
        --             break
        --         end
        --     end
        --     obj:SetText(obj.caption .. ', #' .. pos .. ', ' .. obj.name)
        -- end
        -- return ret
        return inherited.AddChild(self,obj,false, index)

    end


    function TreeViewNode:Add(item, index)
      local newnode
      if (type(item) == "string") then
        local lbl = TextBox:New{text = item; width = "100%"; padding = {2,3,2,2}; minHeight = self.minHeight;}
        newnode = TreeViewNode:New{caption = item; treeview = self.treeview; minHeight = self.minHeight; expanded = self.expanded;}
        newnode:AddChild(lbl, false)
        self:AddChild(newnode, true, index)
      elseif (IsObject(item)) then
        newnode = TreeViewNode:New{caption = ""; treeview = self.treeview; minHeight = self.minHeight; expanded = self.expanded;}
        newnode:AddChild(item, false)
        self:AddChild(newnode, true, index)
      end
      return newnode
    end

end


function widget:Initialize()
    if not WG.Chili then
        Echo('[' .. widget:GetInfo().name .. ']:[Init]:' .. ' Chili is required, shutting down...')
        widgetHandler:RemoveWidget(widget)
        return
    else
        Chili = WG.Chili
        Window = Chili.Window
        TextBox = Chili.TextBox
        TreeViewNode = Chili.TreeViewNode
        Trackbar = Chili.Trackbar

        AddNodeFunctions()

        AddTrackbarFunctions()
        -- Log = WG.LogHandler:New(widget)
        WG.MakeMinizable = MakeMinizable
        WG.ScrollableTextBox = ScrollableTextBox
    end
end



function widget:Shutdown()
    -- RemoveOnLoadMethod()
end 

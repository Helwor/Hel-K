
local ver = 0.1
function widget:GetInfo()
    return {
        name      = "HookFuncs6",
        desc      = "Hook function recursively" .. ver,
        author    = "Helwor",
        date      = "April 2023",
        license   = "GNU GPL, v2",
        layer     = 4000, 
        enabled   = false,  --  loaded by default?
        handler   = true,
    }
end
local Echo = Spring.Echo
Echo('--------------------------------')

local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local debugging = true -- need UtilsFunc.lua
local f = debugging and VFS.Include('LuaUI\\Widgets\\UtilsFunc.lua')
local UPDATE_RATE = 0.1
-- local KEYSIMS

include('keysym.h.lua')
local ESCAPE = KEYSYMS.ESCAPE
KEYSYMS = nil

local sig = '[' .. GetInfo().name .. ']:'
options_path = 'Hel-K/' .. widget:GetInfo().name
local lastSearch = ''

local color_header = {1,1,0,1}
local C_HEIGHT, B_HEIGHT = 15, 22
local header_txt = 'Test'

local UTILS = {}
local GlobalHook = {
    -- items = setmetatable({},{__index=function(self,k) rawset(self,k,{}) return self[k] end}),
    items = {},
    activeHook = false,
}
local HOOK = {
    instances = {},
    count = 0,
}

local UPDATE = {}
local _widgets = {}
local _instances = {}
-- usage on instance creation or deletion, require -OnWidgetState.lua
-- UPDATE[widget] = instance ; add an instance to the widget
-- UPDATE[instance] = nil ; remove the instance, eventually remove the widget if no more instance
-- UPDATE[widget] = nil ; remove the widget and all the instances attached to it


setmetatable( 
    UPDATE,
    {
        __newindex = function(self,k,v)
            if v == nil then
                if _instances[k] then
                    local w = _instances[k]
                    _instances[k] = nil
                    if _widgets[w] then
                        _widgets[w][k] = nil
                        if not next(_widgets[w]) then
                            _widgets[w] = nil
                            GlobalHook.items[w] = nil
                            Echo(sig .. 'widget ' .. w.whInfo.name ..  ' removed from UPDATE by Inst deleting')
                        end
                    end
                    return
                elseif _widgets[k] then
                    Echo(sig .. ' removing all instances of widget ' .. k.whInfo.name)
                    for inst in pairs(_widgets[k]) do
                        _instances[inst] = nil
                        if inst.Delete then
                            inst:Delete(true,true)
                        else
                            Echo('UPDATE',inst,'dont have Delete method')
                        end
                    end
                    Echo(sig .. 'widget ' .. k.whInfo.name .. ' removed from UPDATE by widget shutdown')
                    _widgets[k] = nil
                    if GlobalHook.items[k] then
                        GlobalHook.items[k] = nil
                    end
                end
            else
                if not _widgets[k] then
                    -- Echo(sig .. 'starting folder for widget '.. k.whInfo.name)
                end
                _widgets[k] = _widgets[k] or {}
                -- Echo(sig , ' adding instance ' ,v ,' to folder ' , k)
                _widgets[k][v] = true
                _instances[v] = k
            end
        end,
    }
)



local ownName = widget:GetInfo().name
function WidgetRemoveNotify(w, name, preloading)
    if preloading then
        return
    end
    if name == ownName then
        return
    end
    if _widgets[w] then
        UPDATE[w] = nil
    end

end

function UTILS:SearchCallIn(funcs,source,maxLevel,level, debugMe)
    level = level or 1
    local nextFuncs,n = {},0
    -- stop at the first encountered function that is in the targetted widget
    for f,func in ipairs(funcs) do
        local name,i,item = true,1
        while name do
            name, item = debug.getupvalue(func,i)
            -- 
            if type(item) == 'function' then
                local s = debug.getinfo(item,'S')
                if debugMe then
                    Echo(level,name,item,'target source:',source,'source:', s and s.source,'matching?',s.source == source,s.source,s.linedefined, s.lastlinedefined)
                end
                if s.source == source and s.linedefined~=-1 then
                    if debugMe then
                        Echo('>>> returning first upvalue matching the source: ' .. name)
                    end
                    return item, func, i, name
                end
                n = n + 1
                nextFuncs[n] = item
            end
            i = i + 1
        end
    end
    if level == maxLevel then
        return
    end
    return UTILS:SearchCallIn(nextFuncs,source,maxLevel,level+1,debugMe)
end

----------------------------------------------------------------------------------


function GlobalHook:New(realfunc,caller,upVPos,name,w, isGlobal) -- the function replaced is unique  and the hook must be unique
    -- NOTE! functions are not unique identifier, they have the same value before and after a reload of widget, but they will not get triggered after the reload
    -- have to make global unique hooks per widget and delete them when widget is shutdown

    -- Echo("new ghook ? name is ", name, 'w',w,'folder', self.items[w], 'existing',self.items[w] and self.items[w][realfunc])

    if not self.items[w] then
        self.items[w] = {}
    end
    local ghook = self.items[w][realfunc]
    if ghook then
        -- Echo(sig .. 'Global hook ' .. name .. ' already exists.')
        return ghook
    else
        -- Echo(sig .. 'Creating global hook ' .. name .. '.')
    end
    -- Echo("name is ", name)
    local owners = {}
    local parents = {}
    local master = false
    ghook = {
        active = false,
        realfunc = realfunc,
        caller = caller,
        upVPos = upVPos,
        name = name,
        w = w,
        isGlobal = isGlobal,
    }

    local Echo = Spring.Echo
    local run = function(...)
        local activeHook = GlobalHook.activeHook
        local ourhook
        -- Echo("activeHook.name is ", activeHook and activeHook.name,'num of hooks',table.size(self.items[w]))
        -- local cnt = 0
        -- for k,v in pairs(self.items[w]) do
        --  cnt = cnt + 1
        --  Echo('ghooks',cnt,v.active)
        -- end
        -- local checkedForParents = false
        if activeHook then
            -- for owner, parent in pairs(owners) do -- can be improved ?
            --     -- checkedForParents = true
            --     if parent == activeHook then
            --         ourhook = owner
            --         -- Echo('new ourhook => ',owner.name,' the current hook has for parent the active hook',ourhook.parent.name,'(grd:'..tostring(ourhook.parent.parent and ourhook.parent.parent.name)..')')
            --         GlobalHook.activeHook = ourhook
            --         break
            --     end
            --     -- activeHook.name
            -- end
            ourhook = parents[activeHook] -- an hook is getting triggered, we check if the parent is the activeHook
            if parents[owner] == activeHook then
                ourhook = owner
                -- Echo('new ourhook => ',owner.name,' the current hook has for parent the active hook',ourhook.parent.name,'(grd:'..tostring(ourhook.parent.parent and ourhook.parent.parent.name)..')')
                GlobalHook.activeHook = ourhook
            end
            -- if not ourhook then
            --     Echo('NOT OURS, a current hook is running but the current Active hook ',GlobalHook.activeHook.name, 'is not his parent')
            -- end
        elseif master and not activeHook then
            ourhook = master -- this might  not work correctly if the master can be called elsewhere by another function outside of ther tree
                                    -- calling function should be checked aswell
            -- Echo('No Current active Hook, ourhook master => ',ourhook.name,'parent:' .. tostring(ourhook.parent.name))
            GlobalHook.activeHook = ourhook
        -- else
        --     Echo('somthing else happened ...')
        end
        -- Echo(name,'running', math.round(os.clock()),'our hook?',ourhook,'master?',master,'activeHook?',activeHook)
        -- if name == 'GetUnitViewPosition' then
        --     Echo(
        --         name,'running',math.round(os.clock()),
        --         'ourhook? ' .. tostring(not not ourhook),
        --         'checkedForParents? ' .. tostring(checkedForParents),
        --         'activeHook = >' .. tostring(GlobalHook.activeHook and GlobalHook.activeHook.name),
        --         'owners: ' .. table.subtoline(owners,'name'),
        --         'parent: ' .. tostring(ourhook and ourhook.parent and ourhook and ourhook.parent.name)
        --     )
        -- end
        -- Echo("ActiveHook is ", GlobalHook.activeHook and GlobalHook.activeHook.name,
        --     'parent:' .. tostring(GlobalHook.activeHook and GlobalHook.activeHook.parent and GlobalHook.activeHook.parent.name),
        --     'grdparent:' .. tostring(GlobalHook.activeHook and GlobalHook.activeHook.parent and GlobalHook.activeHook.parent.parent and GlobalHook.activeHook.parent.parent.name),
        --     'this is ' .. (ourhook and 'OUR' or 'NOT our') .. ' hook.'

        -- )
        -- Echo('+++')
        if not ourhook then
            -- Echo('NOT our hook, returning')
            return realfunc(...)
        end
        -- Echo(ourhook.name .. ' start running',math.round(os.clock()))
        GlobalHook.activeHook = ourhook
        ourhook.count = ourhook.count + 1
        local timer = spGetTimer()
        local ret = {realfunc(...)}
        local diffTime = spDiffTimers(spGetTimer(), timer)
        ourhook.time = ourhook.time + diffTime
        -- Echo(math.round(os.clock()), "ourhook.time is ",ourhook.count,ourhook.name, ourhook.time, 'next owner')
        -- local owner,parent = next(owners)
        -- Echo(owner and owner.name, parent and parent.name)
        local before = GlobalHook.activeHook
        GlobalHook.activeHook = not master and ourhook.parent
        -- Echo('<= return of ' .. before.name ..', ActiveHook Become ', tostring(GlobalHook.activeHook and GlobalHook.activeHook.name),
        --     'parent:' .. tostring(GlobalHook.activeHook and GlobalHook.activeHook.parent and GlobalHook.activeHook.parent.name),
        --     'grdparent:' .. tostring(GlobalHook.activeHook and GlobalHook.activeHook.parent and GlobalHook.activeHook.parent.parent and GlobalHook.activeHook.parent.parent.name)
        -- )
        if not GlobalHook.activeHook then
            -- Echo('------------------------')
        end
        if master==ourhook then
            local multiInst = master.multiInst
            if multiInst then
                local start = multiInst.time == 0
                multiInst.time = multiInst.time + diffTime
                multiInst.globalTime = multiInst.startTime + spDiffTimers(spGetTimer(),multiInst.globalTimer)
                if start or multiInst.globalTime >= multiInst.updateTime + UPDATE_RATE then
                    for i,master in ipairs(multiInst.children) do
                        master:UpdateTextBox(true)
                    end
                    multiInst.updateTime = multiInst.globalTime
                end
            else
                local start = master.time == 0
                master.globalTime = master.startTime + spDiffTimers(spGetTimer(),master.globalTimer)
                if start or master.globalTime >= master.updateTime + UPDATE_RATE then
                    master:UpdateTextBox(true)
                    master.updateTime = master.globalTime
                end

            end
        end
        -- Echo(ourhook.name .. ' is done running')
        return unpack(ret)
    end
    -- not using the class for this particular method to keep 'master' and 'owners' locals here for speed
    function ghook:UpdateOwner(owner,add,activeIfOwned,clear)
    -- NOTE: our system to recognize real func and make unique global hook belonging to that func work until the targetted widget is reloaded
    -- , after that, the real func will be recognize but that will not be actually that func getting called anymore, so our global hook will be useless
    -- , therefore we have to clear (clear arg) the global hook when the belonging widget is getting shutdown
        -- Echo('owner',owner.name,'want',add)

        if owner.isMaster then 
            master = add and owner or nil

        end
        local parent = owner.isMaster and owner or owner.parent
        owners[owner] = add and parent or nil
        parents[parent] = add and owner or nil
        local nonext = not  next(owners)
        if activeIfOwned then
            self:Activate(not nonext)
        end
        if nonext and clear then
            -- Echo('clearing ghook')
            -- Echo(self.name,self.realfunc,self.items[w][self.realfunc])
            self.items[w][realfunc] = nil
        end
    end
    ---
    ghook.run = run
    -- if not next(self.items[w]) then
    --     Echo('first global hookregistered', ghook.name)
    -- end
    self.items[w][realfunc] = ghook
    setmetatable(ghook, {__index = GlobalHook})
    return ghook
end

function GlobalHook:Activate(on)
    if self.active == on then
        return
    end
    -- debugging
    -- Echo('global hook ' .. self.name .. ' is ' .. ( on and 'ON' or 'OFF'),self.items[self.w],next(self.items[self.w]))
    --
    if self.isGlobal then
        self.w[self.name] = (on and self.run or self.realfunc)
    else
        debug.setupvalue(self.caller, self.upVPos, (on and self.run or self.realfunc))
    end
    self.active = on
end

function GlobalHook:Delete()
    if not self.items[self.w][self.realfunc] then
        return
    end
    self:Activate(false)
    self.items[self.w][self.realfunc] = nil
    -- if not next(self.items[self.w]) then
    --     Echo('no more global hook registered')
    -- end
end



---------------------------------------------------------------------------



-- NOTE: OnMouseDown for node get triggered also for parents of the node clicked
local function toggle(self, x,y)
    -- Echo('clicked',self.name, self.children[1].text, x,y)
    if y<C_HEIGHT then
        self:Toggle()
    end
    -- self:Select()
    -- local n = self:HitTest(x,y)
    -- if n and n == self then
        -- if not self.parent.root or y<C_HEIGHT then

            -- self:Toggle()
            -- return self
        -- end
    -- end
    -- Echo("n and n.children[1].text is ", n and n.children[1].text)
end
function HOOK:New(target, caller, loc, level, multiInst) 
    if level then
        level = tonumber(level)
    end
    local targetName, callerName, w, upVPos, isGlobal

    local id = {target=tostring(target),caller= tostring(caller),loc= tostring(loc)}
    for instid, inst in pairs(self.instances) do
        if table.kvcompare(instid,id) then
            Echo(sig .. 'the instance ' .. tostring(inst.name),':"' , target, caller, loc,'" already exist')
            -- inst:Switch()
            return inst
        end
    end
    -- Echo("target,caller,loc is ", target,caller,loc)

    if not (target or caller) then
        -- case: whole widget to hook, we make multiple instances, for each callin, into a single window, // NOT multiple panels, now using tree
        loc = loc or widget.whInfo.name

        w = widgetHandler:FindWidget(loc)
        if not w then
            Echo(sig .. 'Widget ' .. tostring(loc) .. ' not found.')
            return false
        end


        local objWin = WG.WINDOW.Tree:New()

        local panel = objWin:Add()
        -- local label = WG.Chili.TextBox:New({text = loc, align = 'left', width = "100%"})
        -- panel:Resize(nil, panel.height + C_HEIGHT)
        -- local node = panel.root:Add(label)
        local node = panel.root:Add(loc)

        -- local label = node.children[1]
        objWin.panel = panel
        -- objWin.node = node

        Echo("node,panel is ", node,panel)
        local multiInst = {
            objWin = objWin,
            node = node,
            isMultiInst=true,
            children={},
            active = false,
            id = id,
            name = loc,
            w = w,
            time = 0, -- no timer since the widget time is just an addition of its CallIns time
            globalTimer = false, -- real time
            globalTime = 0,
            startTime = 0,
            updateTime = 0,
            caption = loc,

        }

        self.instances[id] = multiInst
        node.hook = multiInst

        UPDATE[w] = multiInst
        setmetatable(multiInst, {__index = self})


        node.OnMouseDown = {toggle}


        objWin.win.OnDispose = rawget(objWin.win, 'OnDispose') or {}
        table.insert(objWin.win.OnDispose, function()
                if multiInst and multiInst.Delete then multiInst:Delete() end
        end)

        objWin.searchButton.OnClick = { function() Spring.SendCommands("chat","PasteText /hook:") end }
        objWin.searchButton.caption = "Hook..."



        for name,o in pairs(w) do
            if type(o) == 'function' then
                if widgetHandler[name ..'List'] then
                    local inst = self:New(name, nil, loc, level, multiInst)
                    if inst then
                        inst.parent = multiInst
                        table.insert(multiInst.children, inst)
                    else
                        Echo(sig .. "ERROR, Could,'t make an instance for CallIn " .. name .. ' from widget ' .. loc )
                    end
                end
            end
        end
        return multiInst
    end

    ------
    -- Echo('received params',target, caller, loc)
    target, caller, targetName, callerName, upVPos, w, isGlobal = self:GetArgs(target, caller, loc)
    if not target then
        -- Echo(sig .. 'ERROR, no target in params', target, caller, loc, ' nothing to work on')
        return
    end


    local subInst
    local objWin, panel, root, node

    if not multiInst then
        objWin = WG.WINDOW.Tree:New()
        panel = objWin:Add()
        node = panel.root

    else
        subInst = true
        objWin = multiInst.objWin
        panel = objWin.panel
        node = panel.root.nodes[1]
    end


    -- local label = WG.Chili.TextBox:New({text = targetName, align = 'left'})
    -- local node = node:Add(label)
    -- panel:Resize(nil, panel.height + C_HEIGHT)
    local node = node:Add(targetName)
    -- local label = node.children[1]
    node.OnMouseDown = { toggle }
    local hooktree = {
        name = targetName,
        objWin = not subInst and objWin,
        isWinOwner = not subInst,
        subInst = subInst,
        multiInst = multiInst,
        node = node,
        isMaster = true,
        parent = false,
        -- label = label,
        -- panel = panel,
        func = target, -- the first hook will be applied to the target, then all its children
        caller = caller,
        upVPos = upVPos,
        w = w,
        id = id,
        hooked = false,
        count = 0,
        level = 0,
        time = 0,
        caption = targetName,
        active = false,
        ghook = GlobalHook:New(target, caller, upVPos, targetName, w, isGlobal,callerName),
        globalTimer = not subInst and false, -- real time
        globalTime = not subInst and 0,
        startTime = not subInst and 0,
        updateTime = not subInst and 0,

    }



    hooktree.inst = hooktree
    node.hook = hooktree

    self.instances[id] = hooktree

    setmetatable(hooktree, {__index=self})
    UPDATE[w] = hooktree


    if not subInst then
        objWin.win.OnDispose = rawget(objWin.win, 'OnDispose') or {}
        table.insert(objWin.win.OnDispose, function()
            if hooktree and hooktree.Delete then hooktree:Delete() end
        end)
        objWin.searchButton.OnClick = { function() Spring.SendCommands("chat","PasteText /hook:") end }
        objWin.searchButton.caption = "Hook..."
    end

    

    hooktree:MakeTreeFuncs(level or 6)
Echo('tree made','objWin?',objWin, objWin and objWin.win)
    -- hooktree:UpdateTextBox(true)


    return hooktree
end

function HOOK:GetArgs(target, caller, loc, debugMe)
    local targetName, callerName, w, upVPos, isGlobal 
    if type(loc) == 'string' then
        loc = widgetHandler:FindWidget(loc)
    end
    w = loc or widget
    local source = w.whInfo.filename
    if caller then
        if type(caller) == 'string' then
            callerName = caller
            caller = w[callerName]
        else
            callerName = debug.getinfo(caller,'n').name
        end
        local s = debug.getinfo(caller,'S').short_src
        if s ~= source then
            Echo(sig .. 'looking for ' .. callerName .. ' in ' .. w.whInfo.name .. '...')
            caller = UTILS:SearchCallIn({caller}, source, 5, false, debugMe)
        end
    end

    if type(target) == 'string' then
        targetName = target
        target = w[targetName]
        -- Echo("w,targetName,w[targetName], target is ", w,targetName,w[targetName], target)
    else
        targetName = debug.getinfo(target,'n').name
    end
    local s = debug.getinfo(target,'S').source
    if s ~= source then
        target, caller, upVPos, callerName = UTILS:SearchCallIn({target}, source, 5, false, debugMe)
    end

    if not upVPos then
        if not w[targetName] then
            Echo(sig .. 'no upVPos for ' .. targetName)
            return false
        else
            isGlobal = true
        end
    end
    return target, caller, targetName, callerName, upVPos, w, isGlobal
end



function HOOK:MakeTreeFuncs(maxLevel, level)
    level = level or 1
    local children, n = {n=0}, 0
    self.children = children
    if level > maxLevel then
        return
    end
    local i, name, item = 0, true
    while name do
        i = i + 1
        name, item = debug.getupvalue(self.func, i)
        -- Echo(level,i,"name,item is ", name,item)
        if type(item) == 'function' then
            n = n + 1
            local caption = name
            -- local label = WG.Chili.TextBox:New({text = caption, align = 'left', width = "100%"})
            -- self.panel:Resize(nil, self.panel.height + C_HEIGHT)
            -- local node = (self.node or self.root):Add(label)
            local node = (self.node or self.root):Add(caption)
            local info = debug.getinfo(item,'Sl')
            node.tooltip = '[' .. tostring(info.linedefined) .. ']:' .. tostring(info.source) 
            -- local label = node.children[1]
            node.OnMouseDown = {toggle}

            local child = {
                name = name,
                caller = self.func,
                -- label = label,
                -- panel = self.panel,
                node = node,
                caption = caption,
                level = level,
                func = item,
                parent = self,
                info = debug.getinfo(item),
                inst = self.inst,
                active = false,
                time = 0,
                count = 0,
                ghook = GlobalHook:New(item, self.func, i, name,self.w, false, self.name), 
                w = self.w,
            }
            node.hook = child
            setmetatable(child, {__index = HOOK})
            -- Echo('found',name)
            child:MakeTreeFuncs(maxLevel, level + 1)
            children[n] = child
        end
    end
    children.n = n
end

function HOOK:Switch(on,recursion,clear)


    if on==nil then
        on = not self.active
    end
    self.active = on
    if self.isMultiInst then
        if on then
            self.globalTimer = spGetTimer()
            self.startTime = self.globalTime
        end
        Echo(sig .. self.name .. ' hook instance is ' .. (on and 'ON' or 'OFF') .. '.')
        for i,child in ipairs(self.children) do
            child:Switch(on,true,clear)
        end
        return
    end

    recursion = recursion or self.isMaster


    if self.isMaster then
        if on then 
            if not self.multiInst then
                self.globalTimer = spGetTimer()
                self.startTime = self.globalTime
                Echo(sig .. self.name .. ' hook instance is ' .. (on and 'ON' or 'OFF') .. '.')
            end
        end


    end
    self.ghook:UpdateOwner(self,on,true,clear)
    if recursion then
        for i,child in ipairs(self.children) do
            child:Switch(on,true,clear)
        end
    end
end

function HOOK:UpdateTextBox(recursion)
    -- if type(self.label) ~= 'userdata' then
    --     local panel = self.panel
    --     if panel then
    --         self.label = WG.Chili.TextBox:New({text = self.caption, align = 'left'})
    --         panel:Resize(nil, panel.height + C_HEIGHT)
    --         panel:AddChild(self.label,self.line)
    --     end
    -- end
    -- Echo("self.time is ", self.time)
    if self.count>0 then
        local node = self.node
        
        -- local parent = self.parent
        local parent = self.parent
        -- if self.name == 'DrawGhostSites' then
        --     Echo("node.parent is ", node.parent.caption, 'vs',parentnode.caption)
        -- end

        local parentTime = parent and parent.time or self.globalTime
        local newcaption
        if parentTime then
            newcaption = ('%s %.1f/%.1f = %.0f%% --%d'):format(
                self.caption, self.time, parentTime, parentTime>0 and (self.time / parentTime * 100) or 0, self.count
            )
        else
            newcaption = ('%s %.1f --%d'):format(
                self.caption, self.time, self.count
            )

        end
        -- if newcaption ~= self.label.caption then
        if newcaption ~= node.caption then
            if true or (node.parent.expanded or node.parent.root) then
                -- self.label:SetText(newcaption)
                node:SetText(newcaption)
            end
        end
        local multiInst = self.isMaster and self.multiInst
        if multiInst then
            local newcaption = ('%s %.1f/%.1f = %.0f%%'):format(
                multiInst.caption, multiInst.time, multiInst.globalTime, multiInst.time / multiInst.globalTime * 100
            )
            if newcaption ~=multiInst.caption then
                multiInst.node:SetText(newcaption)
            end
        end
    end
    if recursion then
        for i,child in ipairs(self.children) do
            child:UpdateTextBox(recursion)
        end
    end
end

function HOOK:Clear()
    for w, t in pairs(GlobalHook.items) do
        for realfunc in pairs(t) do
            t[realfunc] = nil
        end
        if not next(t) then
            GlobalHook.items[w] = nil
        end
    end
    for id, inst in pairs(self.instances) do
        if not inst.Delete then
            Echo('instance',inst,' doesnt have Delete method !')
        else
            inst:Delete()
        end
    end
end

function HOOK:Delete(recursion, clearGhook)
    if self.isMultiInst then
        self.instances[self.id] = nil
        UPDATE[self] = nil

        if self.objWin then
            local objWin = self.objWin
            self.objWin = nil
            objWin:Delete(true)
        end
        for i, child in ipairs(self.children) do
            child:Delete(true, clearGhook)
        end
        Echo(sig .. self.name .. ' hook instance is deleted')
        return
    end

    recursion = recursion or self.isMaster
    self:Switch(false,recursion, clearGhook)

    if recursion then
        for i,child in ipairs(self.children) do
            child:Switch(false,true,clearGhook) -- 2nd arg will tell the global hook to destroy if no owners
        end
    end

    if self.isMaster then
        self.instances[self.id] = nil
        UPDATE[self] = nil
        if not self.subInst then
            Echo(sig .. self.name .. ' hook instance is deleted')
        end
        if self.panel then
            local panel = self.panel
            self.panel = nil
            panel:Dispose()
        end
    end
    if self.objWin then
        local objWin = self.objWin
        self.objWin = nil
        objWin:Delete(true)
    end
end
function table:kvcompare(t)
    -- local str = ''
    -- for k, v in pairs(t) do
    --     str = str .. tostring(v) .. ', '
    -- end
    -- local own = ''
    -- for k, v in pairs(self) do
    --     own = own .. tostring(v) .. ', '
    -- end
    -- Echo('verify own:' .. own, 'versus:' .. str)
    -- local cnt = 0
    for k, v in pairs(t) do
        -- cnt = cnt + 1
        -- Echo('verif','#'..cnt,self[k],'versus',v)
        if v~=self[k] then
            return false
        end
    end
    return true
end


function widget:TextCommand(command)
    -- Echo("command is ", command)
    if command:sub(1,5) == "hook:" then
        local str = command:sub(6)
        if str:len()==0 then
            return
        end
        lastSearch = str
        -- local params = {str:match('([^,]-),?([^,]-),?([^,]-),?([^,]-),-([^,]-)')}
        -- local params = str:explode(',')
        local t = {}
        local cnt = 0
        -- for k,v in str:gmatch('(.-),?(.+)') do 
        --  cnt = cnt + 1
        --  -- t[cnt] = k
        --  -- t[cnt+1] = v
        --  Echo(cnt,k,v)
        -- end
        local params = str:split('(,)') -- nil params must be space as /hook: , ,EzTarget for nil, nil, EzTarget
        for k,v in pairs(params) do
            if not v:match('%w') then
                params[k] = nil
            end
        end
        -- Echo("unapck(str:split(',')) is ", unpack(str:split(',')))

        -- Echo(" is ", params[1], params[2], params[3], params[4], params[5])
        local inst = HOOK:New(params[1], params[2], params[3], params[4], params[5])
        if inst then
            inst:Switch()
        else
            Echo('no inst',os.clock())
        end
        if true then
            return
        end
        -- local w = wName:len()==0 and widget or widgetHandler:FindWidget(wName)
        -- local err
        -- if not w then
        --  err = ">> Widget " .. wName .. " not found. <<"
        -- elseif not funcName then
        --  err = ">> Name of CallIn required <<"
        -- elseif not w[funcName] then
        --  err = ">> CallIn " .. funcName .. " not found. <<"
        -- end
        if err then
            if WG.TimeOut then
                WG.TimeOut(function()Spring.SendCommands("chat","PasteText " .. msg)end, 0,0)
                WG.TimeOut(function()Spring.SendCommands("chat","PasteText /hook:" .. lastSearch)end, 1.6,0)
            end
        else
            if WG.TimeOut then
                local msg = ">> HOOKING: " .. w:GetInfo().name .. '.' .. funcName .. ". <<"
                WG.TimeOut(function()Spring.SendCommands("chat","PasteText " .. msg)end, 0,0)
                -- WG.TimeOut(function()Spring.SendCommands('chat')end, 1.6,0)
                WG.TimeOut(function()Spring.SendCommands('chat') end, 1.6,0)
            end

            Method1(wName,funcName)
            window.children[1].OnClick = {function(self) Echo('TEST') end}
            
        end

        -- if w and  then
        --  w = widget


        return true
    end
    return false
end
function widget:Initialize()
    WG.HOOK = HOOK
end
function widget:Shutdown()
    HOOK:Clear()
    WG.HOOK = nil
end

if debugging then
    f.DebugWidget(widget)
end
-----------------------------------------------------------
----TESTING NODES
-- local window0
-- local tree0
-- local label0
-- local Chili



-- function widget:Initialize()
--     Chili = WG.Chili

--     if (not Chili) then
--         widgetHandler:RemoveWidget()
--         return
--     end
--     -- function WG.Chili.TreeViewNode:Update(text)
--     --     if self.children[1].SetText then
--     --         self.children[1].SetText(text)
--     --     end
--     -- end
--     window0 = Chili.Window:New{
--         name = "wnd_profiler",
--         caption = "Profiler";
--         x = 200,
--         y = 450,
--         width  = 400,
--         height = 400,
--         parent = Chili.Screen0,
--         layer = 1,

--         children = {
--             Chili.TextBox:New{
--                 name = "lbl_profiler_samples",
--                 x=0, right=0,
--                 y=0, bottom=-20,
--                 align = "right", valign = "bottom",
--                 caption = "Samples: 0",
--             },
--             Chili.ScrollPanel:New{
--                 x=0, right=0,
--                 y=20, bottom=20,
--                 children = {
--                     Chili.TreeView:New{
--                         name = "tree_profiler",
--                         x=0, right=0,
--                         y=0, bottom=0,
--                         defaultExpanded = true,
--                     },
--                 },
--             },
--             Chili.Button:New{
--                 x=0, right="75%",
--                 y=-20, bottom=0,
--                 caption="start",
--                 OnClick = {AddProfiler},
--             },
--             Chili.Button:New{
--                 x="25%", right="50%",
--                 y=-20, bottom=0,
--                 caption="sedate",
--                 OnClick = {AddSedateProfiler},
--             },
--             Chili.Button:New{
--                 x="50%", right="25%",
--                 y=-20, bottom=0,
--                 caption="reset",
--                 OnClick = {ResetProfiler},
--             },
--             Chili.Button:New{
--                 x="75%", right=0,
--                 y=-20, bottom=0,
--                 caption = "stop",
--                 OnClick = {function() debug.sethook( nil ); profiling = false; rendertree() end},
--             },
--         },
--     }

--     tree0  = window0:GetObjectByName("tree_profiler")
--     label0 = window0:GetObjectByName("lbl_profiler_samples")

--     local l1, l2, l3, l4 = 
--         tree0.root:Add('l1'),
--         tree0.root:Add('l2'),
--         tree0.root:Add('l3'),
--         tree0.root:Add('l4')
--     local l21 = l2:Add'l21'
--     local l211 = l21:Add'l211'
--     local l22 = l2:Add'l22'
--     local l23 = l2:Add'l23'
--     local l41, l42 = l4:Add'l41', l4:Add'l42'
--     local l411 = l41:Add'l411'


--     -- local l21a =  l2:Add('l21a',1)
--     table.insert(l4.OnMouseDown ,
--         function(self)
--             -- self:MoveTo(l2, 1)
--             -- Insert(l211)
--             -- l41:Extract()
--             -- l41:Insert(l21)
--             self:Toggle()
--             -- self.caption = 'jojo'
--             -- self.children[1].text = 'toto'
--             -- self:Update'toto'
--             -- self:SetText('toto')
--             -- self.text = 'toto'
--             -- Echo("#self.children is ", #self.children)

--         end
--     )
--     -- window0:Dispose()
-- end


-- function widget:Shutdown()
--     debug.sethook( nil )
--     if (window0) then
--         window0:Dispose()
--     end
--     HOOK:Clear()
-- end

function scratchpad_load()
    package.path = package.path .. ";.\\Scripts\\?.lua;.\\Scripts\\UI\\?.lua;"

    local lfs = require("lfs")
    local U = require("me_utilities")
    local Skin = require("Skin")
    local DialogLoader = require("DialogLoader")
    local Tools = require("tools")
    local Input = require("Input")

    local isHidden = true
    local keyboardLocked = false
    local window = nil
    local windowDefaultSkin = nil
    local windowSkinHidden = Skin.windowSkinChatMin()
    local panel = nil
    local textarea = nil

    local getCoordsLua =
        [[
        -- thanks MIST! https://github.com/mrSkortch/MissionScriptingTools/blob/master/mist.lua

        local round = function (num, idp)
            local mult = 10^(idp or 0)
            return math.floor(num * mult + 0.5) / mult
        end

        local tostringLL = function (lat, lon, acc, DMS)
            local latHemi, lonHemi
            if lat > 0 then
                latHemi = 'N'
            else
                latHemi = 'S'
            end
        
            if lon > 0 then
                lonHemi = 'E'
            else
                lonHemi = 'W'
            end
        
            lat = math.abs(lat)
            lon = math.abs(lon)
        
            local latDeg = math.floor(lat)
            local latMin = (lat - latDeg)*60
        
            local lonDeg = math.floor(lon)
            local lonMin = (lon - lonDeg)*60
        
            if DMS then	-- degrees, minutes, and seconds.
                local oldLatMin = latMin
                latMin = math.floor(latMin)
                local latSec = round((oldLatMin - latMin)*60, acc)
        
                local oldLonMin = lonMin
                lonMin = math.floor(lonMin)
                local lonSec = round((oldLonMin - lonMin)*60, acc)
        
                if latSec == 60 then
                    latSec = 0
                    latMin = latMin + 1
                end
        
                if lonSec == 60 then
                    lonSec = 0
                    lonMin = lonMin + 1
                end
        
                local secFrmtStr -- create the formatting string for the seconds place
                if acc <= 0 then	-- no decimal place.
                    secFrmtStr = '%02d'
                else
                    local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
                    secFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
                end
        
                return string.format('%02d', latDeg) .. ' ' .. string.format('%02d', latMin) .. '\' ' .. string.format(secFrmtStr, latSec) .. '"' .. latHemi .. '	 '
                .. string.format('%02d', lonDeg) .. ' ' .. string.format('%02d', lonMin) .. '\' ' .. string.format(secFrmtStr, lonSec) .. '"' .. lonHemi
        
            else	-- degrees, decimal minutes.
                latMin = round(latMin, acc)
                lonMin = round(lonMin, acc)
        
                if latMin == 60 then
                    latMin = 0
                    latDeg = latDeg + 1
                end
        
                if lonMin == 60 then
                    lonMin = 0
                    lonDeg = lonDeg + 1
                end
        
                local minFrmtStr -- create the formatting string for the minutes place
                if acc <= 0 then	-- no decimal place.
                    minFrmtStr = '%02d'
                else
                    local width = 3 + acc	-- 01.310 - that's a width of 6, for example.
                    minFrmtStr = '%0' .. width .. '.' .. acc .. 'f'
                end
        
                return string.format('%02d', latDeg) .. ' ' .. string.format(minFrmtStr, latMin) .. '\'' .. latHemi .. '	 '
                .. string.format('%02d', lonDeg) .. ' ' .. string.format(minFrmtStr, lonMin) .. '\'' .. lonHemi
        
            end
        end

        local marks = world.getMarkPanels()
        local result = ""
        for _, mark in pairs(marks) do
            local lat, lon = coord.LOtoLL({
                x = mark.pos.z,
                y = 0,
                z = mark.pos.x
            })
            local alt = round(land.getHeight({
                x = mark.pos.z,
                y = mark.pos.x
            }), 0)
            result = result .. "\n" .. tostringLL(lat, lon, 2, true) .. "\n" .. tostring(alt) .. "m, " .. mark.text .. "\n"
        end
        return result
    ]]

    local scratchpad = {
        logFile = io.open(lfs.writedir() .. [[Logs\Scratchpad.log]], "w")
    }

    function scratchpad.loadConfiguration()
        scratchpad.log("Loading config file...")
        local tbl = Tools.safeDoFile(lfs.writedir() .. "Config/ScratchpadConfig.lua", false)
        if (tbl and tbl.config) then
            scratchpad.log("Configuration exists...")
            scratchpad.config = tbl.config

            -- config migration

            -- add default fontSize config
            if scratchpad.config.fontSize == nil then
                scratchpad.config.fontSize = 14
                scratchpad.saveConfiguration()
            end

            -- move content into text file
            if scratchpad.config.content ~= nil then
                scratchpad.saveContent("0000", scratchpad.config.content, false)
                scratchpad.config.content = nil
                scratchpad.saveConfiguration()
            end
        else
            scratchpad.log("Configuration not found, creating defaults...")
            scratchpad.config = {
                hotkey = "Ctrl+Shift+x",
                windowPosition = {x = 200, y = 200},
                windowSize = {w = 350, h = 150},
                fontSize = 14
            }
            scratchpad.saveConfiguration()
        end
    end

    function scratchpad.getContent(name)
        local path = lfs.writedir() .. [[Scratchpad\]] .. name .. [[.txt]]
        file, err = io.open(path, "r")
        if err then
            scratchpad.log("Error reading file: " .. path)
            return ""
        else
            local content = file:read("*all")
            file:close()
            return content
        end
    end

    function scratchpad.saveContent(name, content, override)
        lfs.mkdir(lfs.writedir() .. [[Scratchpad\]])
        local path = lfs.writedir() .. [[Scratchpad\]] .. name .. [[.txt]]
        local mode = "a"
        if override then
            mode = "w"
        end
        file, err = io.open(path, mode)
        if err then
            scratchpad.log("Error writing file: " .. path)
        else
            file:write(content)
            file:flush()
            file:close()
        end
    end

    function scratchpad.saveConfiguration()
        U.saveInFile(scratchpad.config, "config", lfs.writedir() .. "Config/ScratchpadConfig.lua")
    end

    function scratchpad.log(str)
        if not str then
            return
        end

        if scratchpad.logFile then
            scratchpad.logFile:write("[" .. os.date("%H:%M:%S") .. "] " .. str .. "\r\n")
            scratchpad.logFile:flush()
        end
    end

    local function unlockKeyboardInput(releaseKeyboardKeys)
        if keyboardLocked then
            DCS.unlockKeyboardInput(releaseKeyboardKeys)
            keyboardLocked = false
        end
    end

    local function lockKeyboardInput()
        if keyboardLocked then
            return
        end

        local keyboardEvents = Input.getDeviceKeys(Input.getKeyboardDeviceName())
        DCS.lockKeyboardInput(keyboardEvents)
        keyboardLocked = true
    end

    local function insertCoordinates()
        local coords = net.dostring_in("server", getCoordsLua)
        local lineCountBefore = textarea:getLineCount()

        if coords == "" then
            textarea:setText(textarea:getText() .. "\nNo marks found\n")
        else
            textarea:setText(textarea:getText() .. coords .. "\n")
        end

        -- scroll to the bottom of the textarea
        local lastLine = textarea:getLineCount() - 1
        local lastLineChar = textarea:getLineTextLength(lastLine)
        textarea:setSelectionNew(lastLine, 0, lastLine, lastLineLen)
        scratchpad.saveContent("0000", textarea:getText(), true)
    end

    function scratchpad.createWindow()
        window = DialogLoader.spawnDialogFromFile(lfs.writedir() .. "Scripts\\Scratchpad\\ScratchpadWindow.dlg", cdata)
        windowDefaultSkin = window:getSkin()
        panel = window.Box
        textarea = panel.ScratchpadEditBox
        insertCoordsBtn = panel.ScratchpadInsertCoordsButton

        -- setup textarea
        local skin = textarea:getSkin()
        skin.skinData.states.released[1].text.fontSize = scratchpad.config.fontSize
        textarea:setSkin(skin)

        textarea:setText(scratchpad.getContent("0000"))
        textarea:addChangeCallback(
            function(self)
                scratchpad.saveContent("0000", self:getText(), true)
            end
        )
        textarea:addFocusCallback(
            function(self)
                if self:getFocused() then
                    lockKeyboardInput()
                else
                    unlockKeyboardInput(true)
                end
            end
        )
        textarea:addKeyDownCallback(
            function(self, keyName, unicode)
                if keyName == "escape" then
                    self:setFocused(false)
                    unlockKeyboardInput(true)
                end
            end
        )

        -- setup insert coords button
        insertCoordsBtn:addMouseDownCallback(
            function(self)
                insertCoordinates()
            end
        )

        -- setup window
        window:setBounds(
            scratchpad.config.windowPosition.x,
            scratchpad.config.windowPosition.y,
            scratchpad.config.windowSize.w,
            scratchpad.config.windowSize.h
        )
        scratchpad.handleResize(window)

        window:addHotKeyCallback(
            scratchpad.config.hotkey,
            function()
                if isHidden == true then
                    scratchpad.show()
                else
                    scratchpad.hide()
                end
            end
        )
        window:addSizeCallback(scratchpad.handleResize)
        window:addPositionCallback(scratchpad.handleMove)

        window:setVisible(true)
        scratchpad.hide()
        scratchpad.log("Scratchpad Window created")
    end

    function scratchpad.setVisible(b)
        window:setVisible(b)
    end

    function scratchpad.handleResize(self)
        local w, h = self:getSize()

        panel:setBounds(0, 0, w, h - 20)
        textarea:setBounds(0, 0, w, h - 20 - 20)
        insertCoordsBtn:setBounds(0, h - 40, 50, 20)

        scratchpad.config.windowSize = {w = w, h = h}
        scratchpad.saveConfiguration()
    end

    function scratchpad.handleMove(self)
        local x, y = self:getPosition()
        scratchpad.config.windowPosition = {x = x, y = y}
        scratchpad.saveConfiguration()
    end

    function scratchpad.show()
        if window == nil then
            local status, err = pcall(scratchpad.createWindow)
            if not status then
                net.log("[Scratchpad] Error creating window: " .. tostring(err))
            end
        end

        window:setVisible(true)
        window:setSkin(windowDefaultSkin)
        panel:setVisible(true)
        window:setHasCursor(true)

        -- insert coords only works if the client is the server, so hide the button otherwise
        if DCS.isServer() then
            insertCoordsBtn:setVisible(true)
        else
            insertCoordsBtn:setVisible(false)
        end

        isHidden = false
    end

    function scratchpad.hide()
        window:setSkin(windowSkinHidden)
        panel:setVisible(false)
        textarea:setFocused(false)
        window:setHasCursor(false)
        -- window.setVisible(false) -- if you make the window invisible, its destroyed
        unlockKeyboardInput(true)

        isHidden = true
    end

    function scratchpad.onSimulationFrame()
        if scratchpad.config == nil then
            scratchpad.loadConfiguration()
        end

        if not window then
            scratchpad.log("Creating Scratchpad window hidden...")
            scratchpad.createWindow()
        end
    end

    DCS.setUserCallbacks(scratchpad)

    net.log("[Scratchpad] Loaded ...")
end

local status, err = pcall(scratchpad_load)
if not status then
    net.log("[Scratchpad] Load Error: " .. tostring(err))
end

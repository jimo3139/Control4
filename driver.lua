--[[*****************************************************************************
 * Copyright (c) 2012-2017 Skreens Entertainment Technologies Incorporated - http://skreens.com
 *
 *  Redistribution and use in source and binary forms, with or without  modification, are
 *  permitted provided that the following conditions are met:
 *
 *  Redistributions of source code must retain the above copyright notice, this list of
 *  conditions and the following disclaimer.
 *
 *  Redistributions in binary form must reproduce the above copyright  notice, this list of
 *  conditions and the following disclaimer in the documentation and/or other materials
 *  provided with the distribution.
 *
 *  Neither the name of Skreens Entertainment Technologies Incorporated  nor the names of its
 *  contributors may be used to endorse or promote products derived from this software without
 *  specific prior written permission.

 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
 *  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 *  AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 *  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 *  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 *  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 *  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 *  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
******************************************************************************]]

require "hdmiRoute"
require "remote"
require "utils"
require "c4_driver_declarations"
require "c4_log"
require "c4_common"
require "constants"
require "actions"
require "websock"

JSON = require 'json'
 
function JSON:assert()
	-- We don't want the JSON library to assert but rather return nil in case of parsing errors
end

do	--Globals
	GlobalTicketHandlers = GlobalTicketHandlers or {}
	Timer = Timer or {}
	WS = WS or {}
end

-- Global tables
g_WindowState = {}
g_PortSignal = {}
g_PagePorts = {}
g_PortNumber = {}
g_PortName = {}
--[[=============================================================================
Connect and send to the network
===============================================================================]]
function OnConnectionStatusChanged (idBinding, nPort, strStatus) 

	-- Don't print this if OFFLINE, happens too frequently.
	if(strStatus == 'ONLINE') then
		LogTraceLocal ("MSG044: OnConnectionStatusChanged[" .. idBinding .. " (" .. tostring(nPort) .. ")]: " .. strStatus)
	end
	
	if (idBinding == 6001) then
		WS.CONNECTED = (strStatus == 'ONLINE')

		if (WS.PING) then WS.PING = WS.PING:Cancel () end

		if (WS.CONNECTED) then
			C4:SendToNetwork (idBinding, nPort, WSMakeHeaders ())

			-- Setup a 30 second timer.
			WS.PING = C4:SetTimer (WS.PING_INTERVAL * 1000, function (timer) WSPing () end, true)
		else
			if (WS.RUNNING) then
				g_WebSockStatus = 'ONLINE'
				LogTraceLocal ('MSG721: WS socket disconnected while running')
			else
				g_WebSockStatus = 'OFFLINE'
				--LogTraceLocal ('MSG722: WS socket disconnected while NOT running')
			end
			WS.RUNNING = false
		end
	end
end
--[[=============================================================================
    OnNetworkBindingChanged(idBinding, bIsBound)
  
    Description:
    Function called by Director when a network binding changes state(bound or unbound).
  
    Parameters:
    idBinding(int) - ID of the binding whose state has changed.
    bIsBound(bool) - Whether the binding has been bound or unbound.
  
    Returns:
    None 
===============================================================================]]
function OnNetworkBindingChanged(idBinding, bIsBound)
	local thisIp = C4:GetBindingAddress (idBinding)
	local ipLength = string.len(thisIp)
	if(ipLength == nil) then ipLength = 0 end

	LogTraceLocal ('MSG041: OnNetworkBindingChanged(): idBinding = ' .. tostring(idBinding) .. ' bIsBound = ' .. tostring(bIsBound) .. ' IP = ' .. thisIp)

	-- If true, we have a valid IP from the SDDP from director
	if(bIsBound == true and ipLength ~= 0) then 

		LogTraceLocal ('MSG640: OnNetworkBindingChanged() Bind is true: IP = ' .. thisIp .. ' length = ' .. ipLength)

		-- Get our current SDDP IP Detected.
		local autoIp = Properties ['SDDP IP Detected']

		-- Check our current IP with this one sent to us.
		if (string.find (autoIp, thisIp)) then
			LogTraceLocal ('MSG642: OnNetworkBindingChanged() IP match. No action taken.')
		else
			LogTraceLocal ('MSG643: OnNetworkBindingChanged() IP mismatch. Updating IP Address with = ' .. thisIp)
			C4:UpdateProperty ('SDDP IP Detected', thisIp)
			C4:UpdateProperty ('Static IP Address', thisIp)
			g_WebSockUrl = thisIp
			rediscoverInit(DISCOVER_AUTO)
		end
	else
		LogTraceLocal ('MSG641: OnNetworkBindingChanged() Bind is false: idBinding = ' .. tostring(idBinding) .. ' IP = ' .. thisIp)
	end	
end
--[[=============================================================================
Receive from Network, filter proxy 6001 packets.
===============================================================================]]
function ReceivedFromNetwork (idBinding, nPort, strData)
	local packLen = string.len(strData)
	-- Don't fill up the log with packet ping messages.
	if(packLen > 10) then
		LogTraceLocal("MSG055: ReceivedFromNetwork() Binding ID[" .. idBinding .. " Port(" .. tostring(nPort) .. ")]: Data = " .. strData)
	end	
	if (idBinding == 6001) then
		WSParsePacket (strData) 			-- Decode expected received packets
	end
end
--[[=============================================================================
    Create and Initialize Logging
===============================================================================]]
function OnDriverInit()
	printLocal ('MSG005: Executing OnDriverInit() Function')
end
--[[=============================================================================
    Create and Initialize Logging
===============================================================================]]
function OnDriverEarlyInit ()
	printLocal ('MSG008: Executing OnDriverEarlyInit() Function')
end

--[[=============================================================================
===============================================================================]]
function OnDriverDestroyed ()
	LogTraceLocal ('MSG009: Initializing all properties defined in OnDriverDestroyed ()')
	KillAllTimers ()
end
--[[=============================================================================

===============================================================================]]
function OnDriverLateInit ()
	printLocal ('MSG088: Executing OnDriverLateInit() Function')
	local kaiIpPrim = Properties ['Static IP Address']
	local kaiUnitPath = kaiIpPrim .. "/1/device/name"
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1

	-- Create a logger. NOTE!! Don't put any LOG messages before this code get executed.
	LOG = c4_log:new("WIPPLE ")
	LogTraceLocal ('MSG007: Creating a logger [WIPPLE] in onDriverLateInit()')

	KillAllTimers () -- run here in case of driver update to stop timers from running but being out of scope

	if (C4.AllowExecute) then C4:AllowExecute (true) end

	C4:urlSetTimeout (8)	-- Wait for a URL response, this amount of time.

	-- Default response messages for properties page.
	C4:UpdateProperty ('Get Response', ' ')
	C4:UpdateProperty ('Transfer Status', ' ')

	-- Init all globals here.
	g_HomeKeyType = 'PROGRAM_A'				-- Default intercept key type value RED.
	g_InterceptKeyType = 'PROGRAM_D'		-- Default HOME key type value BLUE.
	g_KaiDefaultLayout = 1					-- Layout setting read from the kai init's default setting.
	g_WebSockLayoutLoaded = 1
	g_Swap1LayoutName = 'HDMI 1'
	g_Swap2LayoutName = 'HDMI 1'
	g_Swap1Layout = 1
	g_Swap2Layout = 1
	g_PrevLayoutNew = 1
	g_PrevLayoutOld = 1
	g_LayoutChangeId = 1
	g_LayoutPosition = 1
	g_KaiActiveBackground = 'Not Avail'		-- Currently active background.
	g_AttachedDevices = 0					-- Number of devices detect on the KAI unit.
	g_KaiDeviceName = 'none'				-- default KAI device name
	g_ConfigOption = CFG_NONE				-- default configuration option.
	g_ActiveAudioIntercept = 1				-- default Audio source
	g_AudioChangePort = 1					-- Audio and device control focus.
	g_AudioPagePosition = 1					-- Page position default 
	g_LayoutTablePtr = 0					-- For the scan for layouts command, this is the pointer.
	g_OsdMode = OSD_OFF						-- Set the default OSD mode.
	g_SwapMode = SWAP_OFF					-- Set the default SWAP mode.
	g_MinInputs = tonumber(MIN_KAI_INPUTS)  -- MIN number of inputs we are dealing with.
	g_MaxInputs = tonumber(MAX_KAI_INPUTS4) -- MAX number of inputs we are dealing with.
	g_WebSockUrl = 'Not Avail'				-- Default web socket URL.
	g_WebSockStatus = 'OFFLINE'				-- Default web socket status.
	g_WebSockLayoutLoadedName = 'Not Avail' -- Default Websocket loaded layout name.
	g_WebsocketInputsLoaded = 0				-- Default websocket number of inputs used for video display.
	g_WebsocketPortLoaded = 0				-- Default websocket HDMI input port loaded for video display.
	g_SwapAnchorPos = 0						-- Default SWAP anchor position.
	g_TogglePrevState = SHOW_OLD			-- Default PREV button toggle value. 
	g_TogglePrevLayout = SHOW_TWO
	g_LayoutLoadedCnt = 0
	g_LayoutLoadingCnt = 0
	g_AudioConfigCnt = 0
	g_AudioMixerCnt = 0
	g_HttpHeaderCnt = 0
	g_OsdTimer = 15							-- Default OSD timer timeout seconds.
	g_pingPongTimer = 15
	g_pingPongState = PINGPONG_OFF
	g_PortsInUse = 0						-- Default Ports in use value. 
	g_SignalFound = 0						-- Default signals found value. 
	g_InterceptMode = INTERCEPT_ON			-- Default Remote keys will be intercepted. 

	interceptCtrl('INTERCEPT_ON')			-- Default to intercept all keys.

	-- Get the sockets packet to init values within it.
	local myIp = Properties ['Static IP Address']
	local tempWebSockUrl = "ws://" .. myIp .. "/1/sockets"
	--WSStart (tempWebSockUrl)			

	-- Get the current Kai default layout ID
	kaiUnitPath = kaiIpPrim .. "/1/layouts/default"
	urlGet (kaiUnitPath, headers, urlGetResponseLayout, {hit = hit})
	LogTraceLocal ('MSG772: URL Kai default Layout ID = ' .. g_KaiDefaultLayout ) 

	-- Build the Kai HDMI Router Table
	buildRouteTable ()

	-- Get the name of the attached Kia unit and send it to Director.
	kaiUnitPath = kaiIpPrim .. "/1/device/name"
	urlGet (kaiUnitPath, headers, urlGetResponseName, {hit = hit})
	LogTraceLocal ('MSG701: URL Kai Name update = ' .. kaiUnitPath )

	-- Collect all property change values..
	for property, _ in pairs (Properties) do
		OnPropertyChanged (property)
	end

	-- Get the Kai's layout inventory
	kaiUnitPath = kaiIpPrim .. "/1/layouts"
	urlGet (kaiUnitPath, headers, urlGetResponseAllLayout, {hit = hit})

end
--[[=============================================================================

===============================================================================]]
function OnPropertyChanged (strProperty) 
	local value = Properties [strProperty]
	local repCount = 1
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local kaiIpPrim = Properties ['Static IP Address']
	local kaiNamePrim = kaiIpPrim .. "/1/device/name"
	local kaiUnitPath = kaiIpPrim .. "/1/layouts/default"
	local hit = 1

	LogTraceLocal ('MSG002: OnPropertyChanged() tag = ' .. strProperty)

	if (value == nil) then
		LogErrorLocal ('ERR090: OnPropertyChanged, nil value for Property: ', strProperty)
		return
	end

	-- Set the logging severity level	
	if (strProperty == 'Log Level') then
		LOG:SetLogLevel(value)

	-- Set the logging Mode	
	elseif (strProperty == 'Log Mode') then
		if(value ~= 'Off') then
			LOG:PrintEnabled()
			LOG:C4LogEnabled()
		end
	
	elseif (strProperty == 'Driver Version') then
		C4:UpdateProperty ('Driver Version', C4:GetDriverConfigInfo ('version'))

	elseif (strProperty == 'Unit Device Name') then
		urlGet (kaiNamePrim, headers, urlGetResponseName, {hit = hit})

	elseif (strProperty == 'Static IP Address') then 
		kaiIpPrim = value
		g_WebSockUrl = "ws://" .. kaiIpPrim .. "/1/sockets"
		C4:UpdateProperty ('SDDP IP Detected', value)

	elseif (strProperty == 'Exchange Currently Loaded Layout') then 
		value = 'Idle'
		C4:UpdateProperty ('Exchange Currently Loaded Layout', value)

	elseif (strProperty == 'On Screen Display Timeout') then 
		if(tonumber(value) > 30) then 
			value = 30 
		end 
		g_OsdTimer = tonumber(value)
		LogTraceLocal ('MSG119: OnPropertyChanged() OSD Timer seconds = ' .. g_OsdTimer)
		C4:UpdateProperty ('On Screen Display Timeout', value)

	elseif (strProperty == 'Default Layout ID') then
		--LogTraceLocal ('WRN019: OnPropertyChanged() Default Layout ID is read-only')
        
	elseif (strProperty == 'Return control to Skreens') then
		if (value == 'Three Dot') then g_InterceptKeyType = "CUSTOM_3"
		elseif (value == 'Red Button') then g_InterceptKeyType = "PROGRAM_A"
		elseif (value == 'Green Button') then g_InterceptKeyType = "PROGRAM_B"
		elseif (value == 'Yellow Button') then g_InterceptKeyType = "PROGRAM_C"
		elseif (value == 'Blue Button') then g_InterceptKeyType = "PROGRAM_D"
		elseif (value == 'Always On') then g_InterceptKeyType = "ALWAYS_ON"
		end

	elseif (strProperty == 'Skreens HOME Layout') then
		if (value == 'Three Dot') then g_HomeKeyType = "CUSTOM_3"
		elseif (value == 'Red Button') then g_HomeKeyType = "PROGRAM_A"
		elseif (value == 'Green Button') then g_HomeKeyType = "PROGRAM_B"
		elseif (value == 'Yellow Button') then g_HomeKeyType = "PROGRAM_C"
		elseif (value == 'Blue Button') then g_HomeKeyType = "PROGRAM_D"
		end

	elseif (strProperty == 'Exchange State') then 
		if (value == "Enabled") then 
			g_pingPongState = PINGPONG_ON 
		elseif (value == "Disabled") then 
			g_pingPongState = PINGPONG_OFF 
		end
		LogTraceLocal ('MSG660: OnPropertyChanged() Exchange State = ' .. g_pingPongState)
		C4:UpdateProperty ('Exchange State', value)

	elseif (strProperty == 'Exchange Time') then 
		g_pingPongTimer = tonumber(value) 
		LogTraceLocal ('MSG661: OnPropertyChanged() Exchange Timer seconds = ' .. g_pingPongTimer)
		C4:UpdateProperty ('Exchange Time', value)
		if(g_ConfigOption == CFG_TIMER_ON) then
			g_OsdTimer = g_pingPongTimer
		end
	
	elseif (strProperty == 'Exchange Layout A') then 
		g_Swap1LayoutName = value
		LogTraceLocal ('MSG662: OnPropertyChanged() Exchange Layout A = ' .. value)
		C4:UpdateProperty ('Exchange Layout A', value)
		if(g_ConfigOption == CFG_TIMER_ON) then
			pingPongControlToggle ()
		end
	
	elseif (strProperty == 'Exchange Layout B') then 
		g_Swap2LayoutName = value
		LogTraceLocal ('MSG663: OnPropertyChanged() Exchange Layout B = ' .. value)
		C4:UpdateProperty ('Exchange Layout B', value)
		if(g_ConfigOption == CFG_TIMER_ON) then
			pingPongControlToggle ()
		end	
	else
		LogTraceLocal ('WRN722: OnPropertyChanged() Tag not implemented = ' ..strProperty)	
	end
end
--[[=============================================================================

===============================================================================]]
function ReceivedFromProxy (idBinding, strCommand, tParams)
	if (idBinding == 5002) then -- Skreens Remote source

		LogTraceLocal ('MSG143: received from Director Skreens Remote, Binding ID = ' .. idBinding .. ' Command = ' .. strCommand)

		-- Intercept mode ON.
		if (strCommand == g_InterceptKeyType) then
			interceptCtrl('INTERCEPT_ON')

		elseif (strCommand == "CONNECT_OUTPUT") then	LogTraceLocal ('WRN030: CONNECT_OUTPUT received, but not used.')
		elseif (strCommand == "GET_VIDEO_PATH") then	LogTraceLocal ('WRN031: GET_VIDEO_PATH received, but not used.')
		elseif (strCommand == "ON") then				LogTraceLocal ('WRN032: ON received, but not used.')
		elseif (strCommand == "SELECT_SOURCE") then		LogTraceLocal ('WRN033: SELECT_SOURCE received, but not used.')
		elseif (strCommand == "WATCH_BUTTON") then		LogTraceLocal ('WRN034: WATCH_BUTTON received, but not used.')
		elseif (strCommand == "LISTEN_BUTTON") then		LogTraceLocal ('WRN035: LISTEN_BUTTON received, but not used.')

		elseif (strCommand == 'SET_INPUT') then 
			-- Get the devices INPUT and OUTPUT proxy IDs.
			local navInput = tonumber(tParams["INPUT"] % 1000)
			local navOutput = tonumber(tParams["OUTPUT"] % 1000)

			-- for 4 port mode, the 4 INPUT device numbers for Kai is 1001 -> 1004
			-- for 16 port mode, the 16 INPUT device numbers for Kai is 1001 -> 1016
			if((navInput >= g_MinInputs) and (navInput <= g_MaxInputs)) then
				LogTraceLocal ('MSG443: New Device Select, Input = ' .. navInput .. ' ID ' .. hdmiInput[navInput][1] .. ' Name = ' .. hdmiInput[navInput][3])
			
				-- If the SET_INPUT device is a device that doesn't go to full screen, check it here.
				if((hdmiInput[navInput][2] == 'FULL') and (g_WebsocketPortLoaded ~= MULTIPLE_INPUTS)) then
					setInputFullScreen(navInput)
					-- Check if the is the C4 red key press.	
				elseif (hdmiInput[navInput][2] == 'HOLD') then
					g_LayoutChangeId = g_KaiDefaultLayout
					layoutChange ()						-- change layout based on the value in "g_LayoutChangeId"
					g_OsdMode = OSD_OFF					-- Set OSD mode.
					interceptCtrl('INTERCEPT_ON')
				end
			else
				LogTraceLocal ('WRN447: SET_INPUT Not Used or invalid, INPUT = ' .. navInput .. ' Output = ' .. navOutput)
			end	
		else
			remoteControl (strCommand, idBinding)
		end	
	elseif (idBinding == 5001) then -- Skreens AV source
		LogTraceLocal ('MSG144: received from Director Skreens AV, Binding ID = ' .. idBinding .. ' Command = ' .. strCommand)
		remoteControlConfig (strCommand, idBinding)
	end
end
--[[=============================================================================

===============================================================================]]
function ReceivedAsync (ticketId, strData, responseCode, tHeaders, strError)
	for k, info in pairs (GlobalTicketHandlers) do
		if (info.TICKET == ticketId) then
			table.remove (GlobalTicketHandlers, k)

			local data, js
			local lenLocal = 0

			for k, v in pairs (tHeaders) do
				if (string.upper (k) == 'CONTENT-TYPE') then
					if (string.find (v, 'application/json')) then
						js = true
					end
				end
				if (string.upper (k) == 'CONTENT-LENGTH') then
					lenLocal = tonumber (v) or 0
				end
			end

			if (js) then
				data = JSON:decode (strData)
				if (data == nil and lenLocal ~= 0) then
					printLocal ('ERR600: ERROR parsing json data = NULL, but indicated size is = ' .. lenLocal)
					strError = 'ERR600: Error parsing response'
				end
			else
				data = strData 
			end

			if (info.CALLBACK) then
				info.CALLBACK (strError, responseCode, tHeaders, data, info.CONTEXT, info.URL)
			end
			return
		end
	end
end

--[[=============================================================================
NavigatorTicketsCallback
===============================================================================]]
function NavigatorTicketsCallback (strError, responseCode, tHeaders, data, info, url)
	 LogTraceLocal ('MSG145: NavigatorTicketsCallback() Data = ' .. data .. ' Info = ' .. info)
	-- this is the callback entry point for async url requests generated by a nav-specific function
	-- this ensures that the right data from the service gets to the right navigator, so simultaneous browses from different navigators won't get lost or confused
	local nav = info.NAV
	local idBinding = info.BINDING
	local room = info.ROOM
	local seq = info.SEQ
	local callback = info.CALLBACK
	local context = info.CONTEXT

	local func = nav [callback]
	local success, ret = pcall (func, nav, idBinding, seq, strError, data, responseCode, tHeaders, context, url)
	if (success) then
		if (ret) then
			local tParams = {}
			tParams.NAVID = nav.navId
			tParams.SEQ = seq
			tParams.DATA = ret
			C4:SendToProxy (idBinding, 'DATA_RECEIVED', tParams)
		end
	else
		DataReceivedError(idBinding, nav.navId, seq, ret)
	end
end

-----------------------------------------------
-----------------------------------------------
-- useful functions
function KillAllTimers ()
	for k,v in pairs (Timer or {}) do
		if (type (timer) == 'userdata') then
			timer:Cancel ()
			Timer [k] = nil
		end
	end
end
--[[=============================================================================
    Display all driver related information.
===============================================================================]]
function displayInfoData ()
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1

	displayTrace()

	-- Get the Kai's layout inventory
	kaiUnitPath = kaiIpPrim .. "/1/layouts"
	urlGet (kaiUnitPath, headers, urlGetResponseAllLayout, {hit = hit})
	displayKaiLayouts()

    print ('Current Audio Change Port       = ' .. g_AudioChangePort )

    print ('PingPong layout #1 ID           = ' .. g_Swap1Layout )
    print ('PingPong layout #2 ID           = ' .. g_Swap2Layout )
    print ('PingPong layout #1 Name         = ' .. g_Swap1LayoutName )
    print ('PingPong layout #2 Name         = ' .. g_Swap2LayoutName )
    print ('PingPong Timer Timeout          = ' .. g_pingPongTimer)
    print ('PingPong Logic Control          = ' .. g_pingPongState )

    print ('Previous Layout New (recent)    = ' .. g_PrevLayoutNew )
    print ('Previous Layout Old (past)      = ' .. g_PrevLayoutOld )
    print ('Current Layout ID               = ' .. g_LayoutChangeId )
    print ('Current Audio Intercept         = ' .. g_ActiveAudioIntercept )
    print ('Attached HDMI Inputs            = ' .. g_AttachedDevices )
    print ('Unit Name Primary               = ' .. g_KaiDeviceName )
    print ('Selected # of MIN ports         = ' .. g_MinInputs )
    print ('Selected # of MAX ports         = ' .. g_MaxInputs )
    print ('Default layout                  = ' .. g_KaiDefaultLayout)
    print ('Current Active Background       = ' .. g_KaiActiveBackground)
    print ('Interception Mode               = ' .. g_InterceptMode)
    print ('Scan for layouts pointer        = ' .. g_LayoutTablePtr)
    print ('Current OSD mode                = ' .. g_OsdMode)
    print ('Default websocket URL           = ' .. g_WebSockUrl)
    print ('websocket Layout Loaded         = ' .. g_WebSockLayoutLoaded) 
    print ('websocket Layout Loaded Name    = ' .. g_WebSockLayoutLoadedName)
    print ('websocket HDMI Channels loaded  = ' .. g_WebsocketInputsLoaded)
	if (g_WebsocketPortLoaded == MULTIPLE_INPUTS) then
		print ('HDMI single port loaded         = Multiple')
	else	
		print ('HDMI single port loaded         = ' .. g_WebsocketPortLoaded)
	end

    print ('Response Layout Loaded Count    = ' .. g_LayoutLoadedCnt)
    print ('Response Layout Loading Count   = ' .. g_LayoutLoadingCnt)
    print ('Response Audio Config Count     = ' .. g_AudioConfigCnt)
    print ('Response Audio Mixer Count      = ' .. g_AudioMixerCnt)
    print ('Response HTTP Header Count      = ' .. g_HttpHeaderCnt)
    print ('Timer OSD timout seconds        = ' .. g_OsdTimer)

end
--[[=============================================================================
    EX_CMD.LUA_ACTION(tParams)

    Description
    Function called for any actions executed by the user from the Actions Tab
    in Composer.

    Parameters
    tParams(table) - Lua table of parameters for the command option

    Returns
    Nothing
===============================================================================]]
function EX_CMD.LUA_ACTION(tParams)
	if (tParams ~= nil) then
		for cmd, cmdv in pairs(tParams) do
			if (cmd == "ACTION" and cmdv ~= nil) then

				if (cmdv == "Action Select Layout") then
					LogErrorLocal("MSG321: Action not requiring service : CMD = " .. cmdv)
				else	
					local status, err = pcall(LUA_ACTION[cmdv], tParams)
					if (not status) then
						LogErrorLocal("ERR775: Execute ACTION command has failed : " .. err .. ' CMD = ' .. cmdv)
					else	
						LogErrorLocal("MSG775: Execute ACTION command Complete : CMD = " .. cmdv)
						end
					break
				end	
			end
		end
	end
end
--[[=============================================================================
    ExecuteCommand(sCommand, tParams)

    Description
    Function called by Director when a command is received for this DriverWorks
    driver. This includes commands created in Composer programming.

    Parameters
    sCommand(string) - Command to be sent
    tParams(table)   - Lua table of parameters for the sent command

    Returns
    Nothing
===============================================================================]]
function ExecuteCommand(sCommand, tParams)

	-- Check for special case commands.
	for par1, par2 in pairs(tParams) do
		if (par1 == "Layouts") then -- This is from the actions tab selecting a new deault layout. 
			local pos = tonumber(par2)
			LogTraceLocal('MSG826: (Actions) Selecting a new default layout = ' .. layoutInventory[pos][1] .. ' ' .. layoutInventory[pos][2])
			kaiDeviceLayout = layoutInventory[pos][1]
			C4:UpdateProperty ('Default Layout ID', kaiDeviceLayout)
			SetNewDefaultLayout (kaiDeviceLayout)
			break
		elseif (par1 == "Skreens Layouts") then  -- This is from the programming tab selecting a new deault layout. 
			local pos = tonumber(par2)
			LogTraceLocal('MSG827: (Programming) Selecting a new default layout = ' .. layoutInventory[pos][1] .. ' ' .. layoutInventory[pos][2])
			kaiDeviceLayout = layoutInventory[pos][1]
			C4:UpdateProperty ('Default Layout ID', kaiDeviceLayout)
			SetNewDefaultLayout (kaiDeviceLayout)
			break
		elseif (par1 == "Front Door") then  -- This is from the programming tab selecting a new deault layout. 
			local pos = tonumber(par2)
			LogTraceLocal('MSG827: (Programming) Selecting a new default layout = ' .. layoutInventory[pos][1] .. ' ' .. layoutInventory[pos][2])
			kaiDeviceLayout = layoutInventory[pos][1]
			C4:UpdateProperty ('Default Layout ID', kaiDeviceLayout)
			SetNewDefaultLayout (kaiDeviceLayout)
			break
		end
	end	

	-- Remove any spaces (trim the command)
	local trimmedCommand = string.gsub(sCommand, " ", "")
	local status, err

	-- if function exists then execute (non-stripped)
	if (EX_CMD[sCommand] ~= nil and type(EX_CMD[sCommand]) == "function") then
		status, err = pcall(EX_CMD[sCommand], tParams)
	-- elseif trimmed function exists then execute
	elseif (EX_CMD[trimmedCommand] ~= nil and type(EX_CMD[trimmedCommand]) == "function") then
		status, err = pcall(EX_CMD[trimmedCommand], tParams)
	elseif (EX_CMD[sCommand] ~= nil) then
		QueueCommand(EX_CMD[sCommand])
		status = true
	else
		LogTraceLocal("MSG554: ExecuteCommand: Unhandled command = " .. g_Command)
		if(par1 ~= nil) then
			LogTraceLocal("MSG551: ExecuteCommand: Unhandled Tag = " .. par1)
		end	
		if(par2 ~= nil) then
			LogTraceLocal("MSG552: ExecuteCommand: Unhandled value = " .. par2)
		end	
		status = true
	end
	
	if (not status) then
		LogErrorLocal("ERR776: Execute CDM command has failed : " .. err)
	end
end


function CustomDoorBell (currentValue, done, search, filter) 
	print (currentValue, search, filter)

	local list = {}
	local back = nil
	local searchable = true

	if (search and filter) then
		CallbackLayouts (currentValue, done, search, filter)
		return
	end

	if (string.sub (currentValue, 1, 7) == 'layouts') then
		back = '' -- Back to the root menu
		for i = 1, 10 do
			table.insert (list, {text = 'Layout #' .. i, value = 'layout' .. i})
		end

	else

		local myLayouts = table.getn (layoutInventory)
		table.insert (list, {text = 'Layout Inventory', value = 'layout', folder = true, selectable = true})

	
		for i = 1, myLayouts do
			if(layoutInventory[i][1] ~= 0) then 
				table.insert (list, {text = 'ID ' .. layoutInventory[i][1] .. ' Name ' .. layoutInventory[i][2], value = tostring(i)})
			end	
		end
	end

	return list, back, searchable
end

function CustomSelectLayouts (currentValue, done, search, filter) 
	print (currentValue, search, filter)

	local list = {}
	local back = nil
	local searchable = true

	if (search and filter) then
		CallbackLayouts (currentValue, done, search, filter)
		return
	end

	if (string.sub (currentValue, 1, 7) == 'layouts') then
		back = '' -- Back to the root menu
		for i = 1, 10 do
			table.insert (list, {text = 'Layout #' .. i, value = 'layout' .. i})
		end

	else

		local myLayouts = table.getn (layoutInventory)
		table.insert (list, {text = 'Layout Inventory', value = 'layout', folder = true, selectable = true})

	
		for i = 1, myLayouts do
			if(layoutInventory[i][1] ~= 0) then 
				table.insert (list, {text = 'ID ' .. layoutInventory[i][1] .. ' Name ' .. layoutInventory[i][2], value = tostring(i)})
			end	
		end
	end

	return list, back, searchable
end

function CallbackLayouts (currentValue, done, search, filter)
	local list = {}
	local back = nil
	local searchable = true

	LogTraceLocal('DBG555: Filter = ' .. filter .. ' search = ' .. g_earch .. ' value = ' .. currentValue)

	if (filter == 'layouts') then
		table.insert (list, {text = 'Layout search result 1 for ' .. g_earch, value = 'search:' .. filter .. ':' .. g_earch .. ':1'})
		table.insert (list, {text = 'Layout search result 2 for ' .. g_earch, value = 'search:' .. filter .. ':' .. g_earch .. ':2'})
	end
	done (list, back, searchable)
end

function pingPongControlToggle ()
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1

	-- If the exchange interface is enabled, execute this function.
	if(g_pingPongState == PINGPONG_ON) then 
		LogTraceLocal ('MSG677: Executing Exchange layout toggle.')

		-- Get the Kai's layout inventory just in case new ones have been added.
		kaiUnitPath = kaiIpPrim .. "/1/layouts"
		urlGet (kaiUnitPath, headers, urlGetResponseAllLayout, {hit = hit})
		--displayKaiLayouts()

		-- Go find the ID for layout A.
		g_Swap1Layout = findKaiLayouts(g_Swap1LayoutName) 
		if (g_Swap1Layout == 0) then 
			LogTraceLocal ('ERR662: Exchange Layout 1 = ' .. g_Swap1LayoutName .. ' Not Found') 
			return
			end

		-- Go find the ID for layout B.
		g_Swap2Layout = findKaiLayouts(g_Swap2LayoutName) 
		if (g_Swap1Layout == 0) then 
			LogTraceLocal ('ERR663: Exchange Layout 2 = ' .. g_Swap2LayoutName .. ' Not Found') 
			return
			end

		-- Set the global time to the exchange timeout.
		g_OsdTimer = g_pingPongTimer
		
		-- Check to if the timer is on, if so, turn it off
		if ( g_ConfigOption == CFG_TIMER_ON) then 
			stopOsdTimer(TIMER_STOP) -- Stop the OSD timer.
			g_ConfigOption = CFG_TIMER_OFF 
			LogTraceLocal ('MSG665: Exchange State is DISABLED.')

		-- Check to if the timer is off, if so, turn it on
		else 
			LogTraceLocal ('MSG664: Exchange State is ENABLED.')
			g_ConfigOption = CFG_TIMER_ON
			startOsdTimer() -- Startup the OSD timer
		end
	end	
end

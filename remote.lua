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
*******************************************************************************]]

require "constants"
require "utils"
require "hdmiRoute"

--[[=============================================================================
Remote control operations for Proxy Skreens Remote
===============================================================================]]
function remoteControl (strCommand, idBinding)
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1
	local hexKey = 1
	local audioString = string.format('{"hdmi_out_stream":%d}', hexKey)
	local audioHdr = {["CONTENT-LENGTH"] = string.len(audioString)}

	local kaiIpPrim = Properties ['Static IP Address']

	if (g_InterceptMode == INTERCEPT_ON) then
		LogTraceLocal ('MSG036: Intercepted Director command rerouted to the Skreens Remote Proxy -> ' .. strCommand )

		-- STAR is used to initializes the defaults audio/video settings and rediscover the current attached device state.
		if (strCommand == 'STAR') then 
			rediscoverInit(DISCOVER_ALL)
			g_LayoutChangeId = g_KaiDefaultLayout
			layoutChange ()						-- change layout based on the value in "g_LayoutChangeId"
			g_OsdMode = OSD_OFF					-- Set OSD mode.

		-- POUND is used like a HOME key on most streaming media remotes. Displays all xx screens.	
		elseif (strCommand == 'POUND') then 
			g_LayoutChangeId = g_KaiDefaultLayout
			layoutChange ()						-- change layout based on the value in "g_LayoutChangeId"
			g_OsdMode = OSD_OFF					-- Set OSD mode.

		-- In Layouts, move right with audio if in some sort of OSD mode.	
		elseif (strCommand == 'RIGHT') then 
			if(g_OsdMode ~= OSD_OFF) then				-- If a right/up is presssed by accident, do nothing.
				if (g_OsdMode == OSD_LAYOUTS) then sendControlChar(CHAR_RIGHT) 
				else sendKeyboardChar(KBD_X)
				end
				restartOsdTimer() -- Restart the timer from the beginning.
			end	

		-- In Layouts, move left with audio if in some sort of OSD mode.	
		elseif (strCommand == 'LEFT') then 
			if(g_OsdMode ~= OSD_OFF) then
				if (g_OsdMode == OSD_LAYOUTS) then sendControlChar(CHAR_LEFT) 
				else sendKeyboardChar(KBD_Z)
				end
				restartOsdTimer() -- Restart the timer from the beginning.
			end

		-- Swap UP sequence 
		elseif (strCommand == 'PULSE_CH_UP' or strCommand == 'UP') then 
			sendControlChar(CHAR_UP) 
			restartOsdTimer() -- Restart the timer from the beginning.

		-- Swap Down sequence.
		elseif (strCommand == 'PULSE_CH_DOWN' or strCommand == 'DOWN') then 
			sendControlChar(CHAR_DOWN)
			restartOsdTimer() -- Restart the timer from the beginning.
 
		-- In Layouts/help/status, select	
		elseif (strCommand == 'ENTER') then 
			processEnterKey()

		-- In Layouts, dismiss layouts	
		elseif (strCommand == 'CANCEL') then 
			OSDDismiss ()						-- Turn off OSD
			g_OsdMode = OSD_OFF					-- Set OSD mode.
			g_SwapMode = SWAP_OFF				-- Set SWAP mode.

		-- Execute OSD layouts pain. Guide for the remote.
		elseif (strCommand == 'GUIDE' or strCommand == 'EJECT' or strCommand == 'OPEN_CLOSE') then 
			OSDPresent (OSD_LAYOUTS)
			g_OsdMode = OSD_LAYOUTS				-- Set OSD mode.

		-- In Layouts, Help screen	
		elseif (strCommand == 'INFO') then 
			OSDPresent (OSD_HELP)
			g_OsdMode = OSD_HELP					-- Set OSD mode.


		-- If this is the preset HOME key, call the API to display it
		elseif (strCommand == g_HomeKeyType) then
			OSDPresent (OSD_HOME)
			g_OsdMode = OSD_HOME					-- Set OSD mode.

		-- In Layouts, Menu screen	
		elseif (strCommand == 'MENU') then 
			scanDirectorDevices ()

		-- If PLAY is pressed while in OSD status mode, go to full screen.
		elseif ((strCommand == 'PLAY') and (g_OsdMode == OSD_STATUS)) then 
			WSStart (g_WebSockUrl)				-- Start the websocket, just in case it has gone to sleep.
			sendKeyboardChar(KBD_F)				-- Move our highlighed to full screen.
			g_OsdMode = OSD_OFF					-- Set OSD mode.
			interceptCtrl('INTERCEPT_OFF')

		-- RECALL is used to jump back and forth to the previous video/audio configs.
		elseif (strCommand == 'RECALL' or strCommand == 'SCAN_REV') then 
			servicePreviousLayout()
			
		-- Move +/- through the audio selections	
		elseif ((strCommand == 'PAGE_UP') or (strCommand == 'PAGE_DOWN')) then
			if (strCommand == 'PAGE_UP') then
				if(g_AudioPagePosition == g_SignalFound) then 
					g_AudioPagePosition = g_MinInputs
					LogTraceLocal ('MSG188: Audio Reset, Pos = ' .. g_AudioPagePosition .. ' Num Ports ' .. g_SignalFound)
				else 
					g_AudioPagePosition = g_AudioPagePosition + 1 
					LogTraceLocal ('MSG189: Audio Change Pos = ' .. g_AudioPagePosition .. ' Num Ports ' .. g_SignalFound)
				end	
			else
				g_AudioPagePosition = g_AudioPagePosition - 1 
				if ((strCommand == 'PAGE_DOWN') and (g_AudioPagePosition == 0)) then 
					g_AudioPagePosition = g_SignalFound
					LogTraceLocal ('MSG190: Audio Change Pos = ' .. g_AudioPagePosition .. ' Num Ports ' .. g_SignalFound)
				end	
			end

			-- Check to make sure we exceed the number of caculated page positions.
			if(g_AudioPagePosition > g_SignalFound) then 
				LogTraceLocal ('ERR200: Audio Change Error at Pos = ' .. g_AudioPagePosition .. ' Max pages ' .. g_SignalFound)
			end
	
			-- Check to see if page audio swich logic is setup.
			if(g_SignalFound ~= 0) then 
				g_AudioChangePort = g_PagePorts[g_AudioPagePosition]

				LogTraceLocal ('MSG270: Audio Page Position = ' .. g_AudioPagePosition .. ' g_AudioChangePort = ' .. g_AudioChangePort .. ' Max pages = ' .. g_SignalFound)

				audioChange ()	-- Change audio source based on the "g_AudioChangePort" value
			else
				LogTraceLocal ('ERR190: Number of ports in use is not initialized.')
			end
		else
			LogTraceLocal ('WRN190: Remote control intercept command not used = ' .. strCommand)
		end	
	else 
		-- Keystokes Will get passed through to the appropricate device.
		local ptrNum = tonumber(g_ActiveAudioIntercept)
		LogTraceLocal ('MSG037: Intercept Mode is OFF. Keystroke passed through to device -> ' .. strCommand .. ' ID = ' .. hdmiInput[ptrNum][1] .. ' Port = ' .. g_ActiveAudioIntercept)
		sendRemoteControl (hdmiInput[ptrNum][1], strCommand, 0, 'Stream') 
	end
end 
--[[=============================================================================
Remote control operations for Proxy Skreens AV
===============================================================================]]
function remoteControlConfig (strCommand, idBinding)
	LogTraceLocal ('MSG736: Director command rerouted to the Skreens AV Proxy -> ' .. strCommand )


	-- Execute OSD layouts pain. Guide for the remote.
	if (strCommand == 'GUIDE' or strCommand == 'EJECT' or strCommand == 'OPEN_CLOSE') then 
		OSDPresent (OSD_LAYOUTS)
		g_OsdMode = OSD_LAYOUTS				-- Set OSD mode.

	-- In Layouts, move right with audio if in some sort of OSD mode.	
	elseif (strCommand == 'RIGHT') then 
		if(g_OsdMode ~= OSD_OFF) then				-- If a right/up is presssed by accident, do nothing.
			sendControlChar(CHAR_RIGHT) 
		end	

	-- In Layouts, move left with audio if in some sort of OSD mode.	
	elseif (strCommand == 'LEFT') then 
		if(g_OsdMode ~= OSD_OFF) then
			sendControlChar(CHAR_LEFT) 
		end

	-- SELECT	
	elseif (strCommand == 'ENTER') then 
		processEnterKey()

	-- Red
	elseif (strCommand == 'PROGRAM_A') then 
		g_OsdTimer = 15
		LogTraceLocal ('MSG801: OnPropertyChanged() OSD Timer seconds = ' .. g_OsdTimer)
		C4:UpdateProperty ('On Screen Display Timeout', 15)
	
	-- Green
	elseif (strCommand == 'PROGRAM_B') then 
		g_OsdTimer = 30
		LogTraceLocal ('MSG801: OnPropertyChanged() OSD Timer seconds = ' .. g_OsdTimer)
		C4:UpdateProperty ('On Screen Display Timeout', 30)
	

	-- Yellow
	elseif (strCommand == 'PROGRAM_C') then
		g_OsdTimer = 60
		LogTraceLocal ('MSG801: OnPropertyChanged() OSD Timer seconds = ' .. g_OsdTimer)
		C4:UpdateProperty ('On Screen Display Timeout', 60)
	

	-- Blue = Set the current layout as the default layout
	elseif (strCommand == 'PROGRAM_D') then 
		g_OsdTimer = 120
		LogTraceLocal ('MSG801: OnPropertyChanged() OSD Timer seconds = ' .. g_OsdTimer)
		C4:UpdateProperty ('On Screen Display Timeout', 120)
	
	-- STOP_LEFT = Set swap layout #1
	elseif (strCommand == 'STOP_LEFT') then 
		GetCurrentLayoutNew ()
		g_Swap1Layout = g_PrevLayoutNew 
	

	-- STOP_RIGHT = Set swap layout #2
	elseif (strCommand == 'STOP_RIGHT') then 
		GetCurrentLayoutNew ()
		g_Swap2Layout = g_PrevLayoutNew 
	

	-- STOP_UP = Enable swap
	elseif (strCommand == 'STOP_UP') then 
		g_ConfigOption = CFG_TIMER_ON
		startOsdTimer() -- Startup the OSD timer

	-- STOP_DOWN = Disable swap
	elseif (strCommand == 'STOP_DOWN') then 
		g_ConfigOption = CFG_TIMER_OFF
		stopOsdTimer(TIMER_STOP) -- Stop the OSD timer.
	
	-- Display Toggle message.	
	elseif (strCommand == 'INFO') then 
		g_OsdTimer = 15
		g_ConfigOption = CFG_TIMER_OFF

		local hdmiId = findKaiLayouts("HDMI 1")
		if(hdmiId ~= 0) then
			g_LayoutChangeId = hdmiId
			layoutChange ()	-- change layout based on the value in "g_LayoutChangeId"
		else
			LogTraceLocal ('ERR993: Searching for HDMI 1 ID has failed.')	
		end	

		OSDPresent (OSD_STATUS)
 
		local nameOne = findKaiLayoutName(g_Swap1Layout) 
		local nameTwo = findKaiLayoutName(g_Swap2Layout) 
		local msg = " Timeout = " .. g_OsdTimer .. " Seconds, Layout # 1 Name " .. nameOne .. ", Layout # 2 Name " .. nameTwo
		sendMessageHdmi1 (msg)
		startOsdTimer() -- Startup the OSD timer
	else 
		g_ConfigOption = CFG_NONE
		LogTraceLocal ('WRN737: Keystroke not used in Skreens AV mode. Key = ' .. strCommand)
	end
end 
--[[=============================================================================
Rediscover all devices and set the defaults init parameters.
===============================================================================]]
function rediscoverInit(initLevel)
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1
	local kaiIpPrim = Properties ['Static IP Address']

	if(initLevel == DISCOVER_ALL) then
		g_LayoutChangeId = g_KaiDefaultLayout
		g_AudioChangePort = g_MinInputs	-- Input 1

		-- Build and Display router table.
		g_AttachedDevices = 0
		buildRouteTable ()
		displayRouteTable ()

		--  Collect all property change values..
		for property, _ in pairs (Properties) do
			OnPropertyChanged (property)
			LogTraceLocal ('MSG762: Property sent to OnPropertyChanged() = ' .. property )
		end
	end	

	-- All init levels execute the code below.

	-- Get the current Kai default layout ID
	local kaiUnitDef = kaiIpPrim .. "/1/layouts/default"
	urlGet (kaiUnitDef, headers, urlGetResponseLayout, {hit = hit})
	LogTraceLocal ('MSG550: Skreens default layout request')

	-- Get the name of the attached Kia unit.
	local kaiUnitPath = kaiIpPrim .. "/1/device/name"
	urlGet (kaiUnitPath, headers, urlGetResponseName, {hit = hit})
	LogTraceLocal ('MSG551: Skreens unit Name update request. ')
end
--[[=============================================================================
Process the keystroke ENTER 
===============================================================================]]
function processEnterKey()

	-- If the SELECT key is pressed when OSD is off, this is when we enter status mode.
	if(g_OsdMode == OSD_OFF) then
		OSDPresent (OSD_STATUS)
		g_OsdMode = OSD_STATUS				-- Set OSD mode.

	-- If we are in status mode the SELECT key has many missions.
	elseif (g_OsdMode == OSD_STATUS) then
		-- If in swap mode, execute the swap and continue with the status enter command.
		if (g_SwapMode == SWAP_ON) then
			sendKeyboardChar("s")
			g_SwapAnchorPos = g_SwapAnchorPos + 1	-- SWAP anchor position.
			if(g_SwapAnchorPos == 2) then
				WSStart (g_WebSockUrl)			-- Start the websocket, just in case it has gone to sleep.
				g_SwapAnchorPos = 0
				g_OsdMode = OSD_OFF				-- Set OSD mode.
				g_SwapMode = SWAP_OFF			-- Set SWAP mode.
			end	
		-- If we are NOT in swap mode, this will initiate the status complete selection.
		else	
			WSStart (g_WebSockUrl)			-- Start the websocket, just in case it has gone to sleep.
			OSDDismiss ()					-- Only dismiss OSD is not in swap mode.
			g_OsdMode = OSD_OFF				-- Set OSD mode.
			interceptCtrl('INTERCEPT_OFF')
		end	

	-- If we are in HELP mode, initiate the help complete selection.
	elseif (g_OsdMode == OSD_HELP) then
		WSStart (g_WebSockUrl)				-- Start the websocket, just in case it has gone to sleep.
		sendKeyboardChar(KBD_F)				-- Move our highlighed to full screen.
		g_OsdMode = OSD_OFF					-- Set OSD mode.
		interceptCtrl('INTERCEPT_OFF')

	-- If we are in LAYOUTS mode, initiate the layouts complete selection.
	elseif (g_OsdMode == OSD_LAYOUTS) then
		WSStart (g_WebSockUrl)				-- Start the websocket, just in case it has gone to sleep.
		sendControlChar(CHAR_RETURN) 
		g_OsdMode = OSD_OFF					-- Set OSD mode.
		interceptCtrl('INTERCEPT_OFF')

	-- just sent the enter, no known OSD mode selected.
	else
		printLocal ('ERR099: Execution of the ENTER key has failed. Unknown OSD mode = ' .. g_OsdMode)
		g_OsdMode = OSD_OFF					-- Set OSD mode.
	end	
end
--[[=============================================================================
Toggle between the current and previous layouts
===============================================================================]]
function servicePreviousLayout()

	-- Toggle Previous state.
	if ( g_TogglePrevLayout == SHOW_OLD) then 
		LogTraceLocal('MSG551: PREV Load state ' .. g_TogglePrevLayout .. ' New ' .. g_PrevLayoutNew .. ' Old ' .. g_PrevLayoutOld .. ' Now ' .. g_LayoutChangeId)
		g_LayoutChangeId = g_PrevLayoutOld
		g_TogglePrevLayout = SHOW_NEW 
	elseif ( g_TogglePrevLayout == SHOW_NEW) then 
		LogTraceLocal('MSG552: PREV Load state ' .. g_TogglePrevLayout .. ' New ' .. g_PrevLayoutNew .. ' Old ' .. g_PrevLayoutOld .. ' Now ' .. g_LayoutChangeId)
		g_LayoutChangeId = g_PrevLayoutNew
		g_TogglePrevLayout = SHOW_OLD 
	end
	layoutChange ()
end
--[[=============================================================================
Start OSD timer
===============================================================================]]
g_GlobalTimer = 0
function startOsdTimer()
	-- Set timer to fire off ONCE in "g_OsdTimer" seconds. Zero indicates no timer.
	if(g_OsdTimer ~= 0) then
		g_GlobalTimer = C4:SetTimer ((g_OsdTimer*1000), function (timer) stopOsdTimer(TIMER_CANCEL) end, false)
		LogTraceLocal('MSG330: OSD Timer has started with a time of seconds = ' .. g_OsdTimer)
	end	
end
--[[=============================================================================
Restart OSD timer
===============================================================================]]
function restartOsdTimer()
	g_GlobalTimer:Cancel() 					-- Stop the timer so we can restart from the beginning.
	-- Set timer to fire off ONCE in "g_OsdTimer" seconds. Zero indicates no timer.
	if(g_OsdTimer ~= 0) then
		g_GlobalTimer = C4:SetTimer ((g_OsdTimer*1000), function (timer) stopOsdTimer(TIMER_CANCEL) end, false)
		LogTraceLocal('MSG331: OSD Timer has restarted with a time of seconds = ' .. g_OsdTimer)
	end	
end
--[[=============================================================================
Timer stop or expired.
===============================================================================]]
function stopOsdTimer(ctrl)
	
	-- If the exchange timer is one, restart the timer.
	if(g_ConfigOption == CFG_TIMER_ON) then
		restartOsdTimer()

		-- Check to see if layout A was the prev layout. If so, setup layout B.
		if ( g_TogglePrevLayout == SHOW_ONE) then 
			g_LayoutChangeId = g_Swap2Layout
			LogTraceLocal ('MSG588: Exchanging to layout A, Name = ' .. g_Swap1LayoutName )
			C4:UpdateProperty ('Exchange Currently Loaded Layout', g_Swap1LayoutName )
			g_TogglePrevLayout = SHOW_TWO

		-- Check to see if layout B was the prev layout. If so, setup layout A.
		else 
			g_LayoutChangeId = g_Swap1Layout
			LogTraceLocal ('MSG589: Exchanging to layout B, Name = ' .. g_Swap2LayoutName )
			C4:UpdateProperty ('Exchange Currently Loaded Layout', g_Swap2LayoutName )
			g_TogglePrevLayout = SHOW_ONE
		end	
		layoutChange ()	-- change layout based on the value in "g_LayoutChangeId"




	elseif(g_OsdTimer ~= 0) then
		if(ctrl == TIMER_CANCEL) then 
			OSDDismiss ()						-- Turn off OSD
			g_OsdMode = OSD_OFF					-- Set OSD mode.
			g_SwapMode = SWAP_OFF				-- Set SWAP mode.
			LogTraceLocal('MSG332: OSD Timer has expired, and will cancel the OSD')
		elseif(ctrl == TIMER_STOP) then 
			LogTraceLocal('MSG333: OSD Timer has stopped normally.')
			g_GlobalTimer:Cancel()				-- Stop the timer, but do nothing.
		end
	end	
end

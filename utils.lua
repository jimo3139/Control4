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
g_TraceBuffer = "" --  Use this to view lua log during loading. 

require "constants"

layoutInventory = {}
-- Layout					ID		NAME			Group
layoutInventory[1]   = {	0,		'NULL',			'NULL'}
layoutInventory[2]   = {	0,		'NULL',			'NULL'}
layoutInventory[3]   = {	0,		'NULL',			'NULL'}
layoutInventory[4]   = {	0,		'NULL',			'NULL'}
layoutInventory[5]   = {	0,		'NULL',			'NULL'}
layoutInventory[6]   = {	0,		'NULL',			'NULL'}
layoutInventory[7]   = {	0,		'NULL',			'NULL'}
layoutInventory[8]   = {	0,		'NULL',			'NULL'}
layoutInventory[9]   = {	0,		'NULL',			'NULL'}
layoutInventory[10]  = {	0,		'NULL',			'NULL'}
layoutInventory[11]  = {	0,		'NULL',			'NULL'}
layoutInventory[12]  = {	0,		'NULL',			'NULL'}
layoutInventory[13]  = {	0,		'NULL',			'NULL'}
layoutInventory[14]  = {	0,		'NULL',			'NULL'}
layoutInventory[15]  = {	0,		'NULL',			'NULL'}
layoutInventory[16]  = {	0,		'NULL',			'NULL'}

--[[=============================================================================
Split up a string based on the input paremeters
===============================================================================]]
function string:split( inSplitPattern, outResults )
	if not outResults then
		outResults = { }
	end
	local theStart = 1
	local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
	while theSplitStart do
		table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
		theStart = theSplitEnd + 1
		theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
	end
	table.insert( outResults, string.sub( self, theStart ) )
	return outResults
end
--[[=============================================================================
Print contents of `tbl`, with indentation.
`indent` sets the initial level of indentation.
===============================================================================]]
function tprint (tbl, indent)
	LogTraceLocal ('MSG055: tprint() Function Entry point' )
	local myNum
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
		formatting = string.rep("  ", indent) .. k .. ": "
		if type(v) == "table" then	
			LogTraceLocal('MSG019: ' .. formatting)
			tprint(v, indent+1)
		elseif type(v) == 'boolean' then
			LogTraceLocal('MSG088: ' .. formatting .. tostring(v))      
		else
			if (v ~= nil) then
				myNum = tostring(v)
				LogTraceLocal('MSG020: ' .. formatting .. myNum)
			else	
				LogTraceLocal('MSG021: ' .. formatting .. ' NULL')
			end	
		end
	end
end
--[[=============================================================================
HTTP GET
===============================================================================]]
function urlGet (url, headers, callback, context)
	local info = {}
	if (type (callback) == 'function') then
		info.CALLBACK = callback
	end
	info.CONTEXT = context
	info.URL = url
	info.METHOD = 'GET'
	info.TICKET = C4:urlGet (url, headers or {}, false)

	if (info.TICKET and info.TICKET ~= 0) then
		table.insert (GlobalTicketHandlers, info)
	else
		dbg ('C4.Curl error: ' .. info.METHOD .. ' ' .. url)
		if (callback) then
			callback ('No ticket', nil, nil, '', context, url)
		end
	end
end

--[[=============================================================================
HTTP POST
===============================================================================]]
function urlPost (url, data, headers, callback, context)
	LogTraceLocal ('MSG106: urlPost() options received, URL = ' .. url .. ', DATA = ' .. data )
	local info = {}
	if (type (callback) == 'function') then
		info.CALLBACK = callback
	end

	info.CONTEXT = context
	info.URL = url
	info.METHOD = 'POST'
	info.TICKET = C4:urlPost (url, data, headers or {}, false)
	if (info.TICKET and info.TICKET ~= 0) then
		table.insert (GlobalTicketHandlers, info)
	else
		dbg ('C4.Curl error: ' .. info.METHOD .. ' ' .. url)
		if (callback) then
			callback ('No ticket', nil, nil, '', context, url)
		end
	end
end


--[[=============================================================================
HTTP PUT
===============================================================================]]
function urlPut (url, data, headers, callback, context)

	-- Split up the URL path.
	local myTable = url:split("/")
	for i = 1, #myTable do
	end

	-- Don't execute this PUT if the IP is not initialized.
	if (myTable[1] == '0.0.0.0') then 
		LogTraceLocal ('WRN100: urlPut() Invalid IP. URL = ' .. url .. ' Layout = ' .. data )
		return
	end	

	local info = {}
	if (type (callback) == 'function') then
		info.CALLBACK = callback
	end

	info.CONTEXT = context
	info.URL = url
	info.METHOD = 'PUT'
	info.TICKET = C4:urlPut (url, data, headers or {}, false)
	if (info.TICKET and info.TICKET ~= 0) then
		table.insert (GlobalTicketHandlers, info)
	else
		dbg ('C4.Curl error: ' .. info.METHOD .. ' ' .. url)
		if (callback) then
			callback ('No ticket', nil, nil, '', context, url)
		end
	end
end

--[[=============================================================================
HTTP DELETE
===============================================================================]]
function urlDelete (url, headers, callback, context)
	local info = {}
	if (type (callback) == 'function') then
		info.CALLBACK = callback
	end
	info.CONTEXT = context
	info.URL = url
	info.METHOD = 'DELETE'
	info.TICKET = C4:urlDelete (url, headers or {}, false)
	if (info.TICKET and info.TICKET ~= 0) then
		table.insert (GlobalTicketHandlers, info)
	else
		dbg ('C4.Curl error: ' .. info.METHOD .. ' ' .. url)
		if (callback) then
			callback ('No ticket', nil, nil, '', context, url)
		end
	end
end

--[[=============================================================================

===============================================================================]]
function urlCustom (url, method, data, headers, callback, context)
	local info = {}
	if (type (callback) == 'function') then
		info.CALLBACK = callback
	end
	info.CONTEXT = context
	info.URL = url
	info.METHOD = method
	info.TICKET = C4:urlCustom (url, method, data, headers or {}, false)
	if (info.TICKET and info.TICKET ~= 0) then
		table.insert (GlobalTicketHandlers, info)
	else
		dbg ('C4.Curl error: ' .. info.METHOD .. ' ' .. url)
		if (callback) then
			callback ('No ticket', nil, nil, '', context, url)
		end
	end
end
--[[=============================================================================
Send Device Control
===============================================================================]]
function sendRemoteControl (devID, opcode, value, ctrl)
	LogTraceLocal ('MSG833: sendRemoteControl() Pass Thru to device Id = ' .. devID .. ' opcode = ' .. opcode .. ' Value = ' .. value .. ' Control = ' .. ctrl)
	-- If this is a streaming video type xfer, we don't need a value.
	if(ctrl == 'Stream') then
		C4:SendToDevice (devID, opcode, {})
	-- This type of xfer requires a value.
	else
		C4:SendToDevice (devID, opcode, {CHANNEL = value})
	end	
end
--[[=============================================================================
Send Device Control
===============================================================================]]
function sendChannelControl (devID, value, ctrl)
	LogTraceLocal ('MSG836: sendChannelControl() Pass Thru to device Id = ' .. devID .. ' Value = ' .. value .. ' Control = ' .. ctrl)
	-- If this is a streaming video type xfer, we don't need a value.
	if(ctrl == 'Stream') then
		C4:SendToDevice (devID, 'SET_CHANNEL', {})
	-- This type of xfer requires a value.
	else
		C4:SendToDevice (devID, 'SET_CHANNEL', {CHANNEL = value})
	end	
end
--[[=============================================================================
Send channel change. If "channel" = 0, don't do anything here.
===============================================================================]]
function sendChannelChange (channel,port)
	local sendDigit = 0

	if(channel ~= 0) then
		local myChan = tonumber(channel)
		sendChannelControl (hdmiInput[port][1], myChan, 'Cable')
			LogTraceLocal ('MSG769: Xfering channel request = ' .. myChan .. ' Device = ' ..hdmiInput[port][1])
	else
		LogTraceLocal ('MSG763: Channel Change response is zero, do nothing. Chan = ' .. channel .. ' port ' .. port)
	end	
end
--[[=============================================================================
Local LogTraceLocal function()
===============================================================================]]
function LogTraceLocal(String)
	String = stripControlCodes( String ) -- remove non printable characters.
	local stamp = getTimeStamp()
	print (String)
	LogTrace (stamp .. String)
	local bufLen = string.len(g_TraceBuffer)
	-- Just get the startup lua log, then stop recording.
	if(bufLen < 15000) then
		-- truncate string so we can just save the start of the message.
		local msgString = string.sub(String, 0, 80)
		g_TraceBuffer = g_TraceBuffer .. 'TRC-' .. msgString  .. '\r' -- Use this to view lua log during loading.
	end	
end
--[[=============================================================================
Local printLocal function()
===============================================================================]]
function printLocal(String)
	local stamp = getTimeStamp()
	print (stamp .. String)
end
--[[=============================================================================
Local LogError function()
===============================================================================]]
function LogErrorLocal(String)
	local stamp = getTimeStamp()
	LogError (stamp .. String)
end
--[[=============================================================================
Get and format the timestamp
===============================================================================]]
function getTimeStamp()

	-- local tf=os.date('%Y-%m-%d %H:%M:%S ',os.time())
	local tf=(string.format("TS%1.4f ", os.clock()))
	return tf
end
--[[=============================================================================
Sleeps (seconds) delay.
===============================================================================]]
function sleep(n)  -- seconds
	local clock = os.clock
	local t0 = clock()
	while clock() - t0 <= n do end
end
--[[=============================================================================
Send control character to the Kai
===============================================================================]]
function sendControlChar(opcode)
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiPathPrim = kaiIpPrim .. "/1/keyboard/control-character"
	local layoutStr = ('{"control_character":"' .. opcode .. '"}')
	urlPost (kaiPathPrim, layoutStr, headers, urlPostResponse, {repCount = repCount})
	LogTraceLocal ('MSG647: Control Character POST Present string sent = ' .. layoutStr .. ' URL = ' .. kaiPathPrim)
end
--[[=============================================================================
Send keyboard character to the Kai
===============================================================================]]
function sendKeyboardChar(opcode)
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiPathPrim = kaiIpPrim .. "/1/keyboard/text" 
	local layoutStr = ('{"text": "' .. opcode .. '"}')
	urlPost (kaiPathPrim, layoutStr, headers, urlPostResponse, {repCount = repCount})
	LogTraceLocal ('MSG643: Keyboard Character POST Present string sent = ' .. layoutStr .. ' URL = ' .. kaiPathPrim)
end
--[[=============================================================================

===============================================================================]]
function SetNewDefaultLayout (myId)
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiIpPrim = Properties ['Static IP Address']
	local kaiUnitDef = kaiIpPrim .. "/1/layouts/default"
	local layoutStr = ('{"layout_id":' .. tonumber(myId) .. '}')
	urlPut (kaiUnitDef, layoutStr, headers, urlPutResponseVideo, {repCount = repCount})
	LogTraceLocal ('MSG757: Change Default Layout String = ' .. layoutStr .. ' Path = ' .. kaiUnitDef)
end
--[[=============================================================================
Get the Currently loaded layout New ID
===============================================================================]]
function GetCurrentLayoutNew ()
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiUnitPath = kaiIpPrim .. "/1/window-manager/layout"
	urlGet (kaiUnitPath, headers, urlGetResponseCurrent, {repCount = repCount})
	LogTraceLocal ('MSG611: url GET Current Layout Request = ' .. kaiUnitPath)
end
--[[=============================================================================
Get the Current audio source in the Kai
===============================================================================]]
function GetCurrentAudio ()
	-- Get the current Kai active Audio source name
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1
	local kaiUnitName = kaiIpPrim .. "/1/audio-config"
	urlGet (kaiUnitName, headers, urlGetResponseAudio, {hit = hit})
	LogTraceLocal ('MSG572: URL Kai Active Audio request = ' .. kaiUnitName )
end
--[[=============================================================================
Get the Current background in the Kai
===============================================================================]]
function GetCurrentBackground ()
	-- Get the current Kai active Background ID
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local hit = 1
	local kaiUnitName = kaiIpPrim .. "/1/window-manager/background"
	urlGet (kaiUnitName, headers, urlGetResponseBackground, {hit = hit})
	LogTraceLocal ('MSG571: URL Kai Active Background request = ' .. kaiUnitName )
end
 --[[=============================================================================
Clear all layouts
===============================================================================]]
function clrAllLayouts ()
	local repCount = 1
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}

	local kaiIpPrim = Properties ['Static IP Address']
	local kaiPathPrim = kaiIpPrim .. "/1/osd"
	urlDelete (kaiPathPrim, headers, urlDeleteResponse, {repCount = repCount})

	local kaiPathPrim = kaiIpPrim .. "/1/window-manager/layout"
	urlDelete (kaiPathPrim, headers, urlDeleteResponse, {repCount = repCount})
end
--[[=============================================================================
 Create each window in the appropriate position
===============================================================================]]
function createWindow(myWindow)
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiIpPrim = Properties ['Static IP Address']
	local kaiPathPrim = kaiIpPrim .. "/1/windows"
	urlPost (kaiPathPrim, myWindow, headers, urlPostResponse, {repCount = repCount})
end
--[[=============================================================================
Set HDMI input to full screen
===============================================================================]]
function setInputFullScreen(input)
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiPathPrim = kaiIpPrim .. "/1/voice-commands"
	local layoutStr = ('{"command":"full_screen_hdmi","hdmi_port":' .. input  .. '}')
	urlPost (kaiPathPrim, layoutStr, headers, urlPostResponse, {repCount = repCount})
	LogTraceLocal ('MSG648: Control Character POST Present string sent = ' .. layoutStr .. ' URL = ' .. kaiPathPrim)
end
--[[=============================================================================
Change layout based on the value in global g_LayoutChangeId
===============================================================================]]
function layoutChange ()
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1 
	local kaiIpPrim = Properties ['Static IP Address']
	local kaiPathPrim = kaiIpPrim .. "/1/window-manager/layout"

	local hexKey = tonumber(g_LayoutChangeId)
	local layoutStr = ('{"id":' .. hexKey .. '}')
	urlPut (kaiPathPrim, layoutStr, headers, urlPutResponseVideo, {repCount = repCount})
	LogTraceLocal ('MSG150: Change Layout String = ' .. layoutStr .. ' HDMI Input = ' .. hexKey)
end
--[[=============================================================================
Change audio based on the value in global g_AudioChangePort
===============================================================================]]
function audioChange ()
	local hexKey = tonumber(g_AudioChangePort)
	local audioString = string.format('{"hdmi_out_stream":%d}', hexKey)
	local audioHdr = {["CONTENT-LENGTH"] = string.len(audioString)}
	local repCount = 1

	local kaiIpPrim = Properties ['Static IP Address']
	local kaiAudioPrim = kaiIpPrim .. "/1/audio-config"

	LogTraceLocal ('MSG399: URL Audio = ' .. kaiAudioPrim )

	audioStringP = string.format('{"hdmi_out_stream":%d}', g_AudioChangePort)
	LogTraceLocal ('MSG422: Change Audio string sent = ' .. audioStringP .. ' URL = ' .. kaiAudioPrim)
	
	urlPut (kaiAudioPrim, audioStringP, audioHdr, urlPutResponseAudio, {repCount = repCount})
end
--[[=============================================================================
OSD Present
===============================================================================]]
function OSDPresent (strCommand)
	-- Start up the timer from the beginning.
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiPathPrim = kaiIpPrim .. "/1/osd"
	local layoutStr = ('{"screen":"' .. strCommand .. '"}')
	urlPost (kaiPathPrim, layoutStr, headers, urlPostResponse, {repCount = repCount})
	LogTraceLocal ('MSG640: OSD POST Present string sent = ' .. layoutStr .. ' URL = ' .. kaiPathPrim)
	startOsdTimer() -- Startup the OSD timer
end
--[[=============================================================================
OSD Dismiss
===============================================================================]]
function OSDDismiss ()
	stopOsdTimer(TIMER_STOP) -- Stop the OSD timer.
	local repCount = 1
	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}

	local kaiPathPrim = kaiIpPrim .. "/1/osd"
	urlDelete (kaiPathPrim, headers, urlDeleteResponse, {repCount = repCount})
	LogTraceLocal ('MSG641: OSDDismiss() Executed. UrlDelete() URL = ' ..kaiPathPrim)
end
--[[=============================================================================
Kill our local timer.
===============================================================================]]
function killLocalTimer()
	LogTraceLocal ('MSG440: killLocalTimer() OSD dismissed Timer executed, Duration waited = ' .. OSD_delay .. ' Seconds')
	keyPressTimer:Cancel()
end
--[[=============================================================================
Display the Kai layout IDs and names
===============================================================================]]
function displayKaiLayouts()
	local flag = 0
	local myLayouts = table.getn (layoutInventory)
	if(myLayouts ~= 0) then
		LogTraceLocal ('MSG790: Layout inventory MAX size = ' .. myLayouts)
		for i = 1, myLayouts do
			if(layoutInventory[i][1] ~= 0) then
				flag = 1
				print ( 'MSG630: Layout ID ' .. layoutInventory[i][1] .. ' Name ' .. layoutInventory[i][2].. ' Group ' .. layoutInventory[i][3])
			end
		end
		if(flag == 0) then
			LogTraceLocal ('ERR791: Layout inventory is empty.')
		end	
	else
		LogTraceLocal ('ERR790: Layout inventory count = zero.')
	end	
end
--[[=============================================================================
Find a Kai layout ID based on name
===============================================================================]]
function findKaiLayouts(name)
	name = string.upper(name)
	print ("Looking for " .. name)
	local invName = ""
	local hdmi_ID = 0
	local myLayouts = table.getn (layoutInventory)
	if(myLayouts ~= 0) then
		for i = 1, myLayouts do
			if(layoutInventory[i][1] ~= 0) then
				invName = string.upper(layoutInventory[i][2])
				if(invName == name) then 
					hdmi_ID = layoutInventory[i][1]
					print ( 'MSG990: Layout ID ' .. layoutInventory[i][1] .. ' Name ' .. layoutInventory[i][2].. ' Group ' .. layoutInventory[i][3])
					break
				end	
			end
		end
	else
		LogTraceLocal ('ERR990: Layout inventory count = zero.')
	end
	return hdmi_ID
end
--[[=============================================================================
Find a Kai layout NAME based on ID
===============================================================================]]
function findKaiLayoutName(id)
	local hdmi_name = "undefined"
	local myLayouts = table.getn (layoutInventory)
	for i = 1, myLayouts do
		if(layoutInventory[i][1] ~= 0) then
			if(layoutInventory[i][1] == id) then
				hdmi_name = layoutInventory[i][2]
				print ( 'MSG990: Layout ID ' .. layoutInventory[i][1] .. ' Name ' .. layoutInventory[i][2].. ' Group ' .. layoutInventory[i][3])
				break
			end	
		end
	end
	return hdmi_name
end
--[[=============================================================================
Set the command interception mode.
===============================================================================]]
function interceptCtrl(ctrl)
	local ptrNum = tonumber(g_ActiveAudioIntercept)

	-- If we are turning interceptions off, and the key type is not ALWAYS_ON, sent keys to the device.
	if(ctrl == 'INTERCEPT_OFF' and g_InterceptKeyType ~= "ALWAYS_ON") then 
		g_InterceptMode = INTERCEPT_OFF		-- Remote keys will NOT be intercepted. 
		LogTraceLocal ('MSG341: Interception is OFF. All commands are being sent to device ID = ' .. hdmiInput[ptrNum][1] .. ' ' .. hdmiInput[ptrNum][3] .. 'Idx' .. ptrNum)
	else	
		g_InterceptMode = INTERCEPT_ON		-- Remote keys will be intercepted. 
		LogTraceLocal ('MSG340: Interception is ON. All commands are handled by the skreens proxy')
	end
end
--[[=============================================================================
Send the Director's proxy inventory to Kia
===============================================================================]]
function sendProxyInventory (strDevices)

	local kaiIpPrim = Properties ['Static IP Address']
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1
	local kaiPathPrim = kaiIpPrim .. "/1/c4-devices"
	local layoutStr = ('{"screen":"' .. strDevices .. '"}')
	urlPost (kaiPathPrim, strDevices, headers, urlPostResponse, {repCount = repCount})
	LogTraceLocal ('MSG617: Proxy Inventory POST Present string sent URL ' .. kaiPathPrim)
end

--[[=============================================================================
Response messages
===============================================================================]]
function urlGetResponseName (strError, responseCode, tHeaders, data, context, url)
	if (data.name ~= nil) then
		g_KaiDeviceName = data.name
	else
		g_KaiDeviceName = 'Not Available'
	end	
	C4:UpdateProperty ('Unit Device Name', g_KaiDeviceName)
	C4:UpdateProperty ('Get Response', 'Get Response : ' .. responseCode .. ' Name = ' .. g_KaiDeviceName)
end

function urlGetResponseBackground (strError, responseCode, tHeaders, data, context, url)
	if (data.type ~= nil) then	g_KaiActiveBackground = data.type
	else						g_KaiActiveBackground = 'Not Available'
	end	
end

function urlGetResponseLayout (strError, responseCode, tHeaders, data, context, url)
	local kaiDeviceLayout = 'Not Found' 
	if (data.layout_id ~= nil) then
		kaiDeviceLayout = data.layout_id
	end	
	C4:UpdateProperty ('Default Layout ID', kaiDeviceLayout)

	-- If we have a real number back from Kai, config our layout and parameters.
	if(kaiDeviceLayout ~= 'Not Found') then 
		g_KaiDefaultLayout = kaiDeviceLayout	-- Save the default layout ID.
		g_PrevLayoutOld = g_KaiDefaultLayout	-- Set the PREV old layout to the default
		g_PrevLayoutNew = g_KaiDefaultLayout	-- Set the PREV new layout to the default
		g_LayoutChangeId = g_KaiDefaultLayout	-- Default active layout should be Kai's default layout.
		layoutChange() 
	else print('ERR092: Default layout Not Found. Received = ' .. kaiDeviceLayout)   	
	end	
	LogTraceLocal ('RET758: Response from Default layout request = ' .. kaiDeviceLayout)
end 

function urlGetResponseCurrent (strError, responseCode, tHeaders, data, context, url)
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local repCount = 1

	local kaiDeviceLayout = 'Not Found' 
	if (data.id == nil) then kaiDeviceLayout = 'NULL' 
	else
		kaiDeviceLayout = data.id	-- local
		g_LayoutChangeId = data.id	-- global
		g_PrevLayoutNew =  data.id	-- Use this for the previous layout ID
		LogTraceLocal ( 'RET336: Set Current Layout New = ' .. g_PrevLayoutNew) 

		if(g_ConfigOption == CFG_TIMER_OFF) then
			local kaiIpPrim = Properties ['Static IP Address']
			local kaiUnitDef = kaiIpPrim .. "/1/layouts/default"
			local layoutStr = ('{"layout_id":' .. tonumber(g_PrevLayoutNew) .. '}')
			urlPut (kaiUnitDef, layoutStr, headers, urlPutResponseVideo, {repCount = repCount})
			LogTraceLocal ('MSG157: Change Default Layout String = ' .. layoutStr .. ' Path = ' .. kaiUnitDef)
		end	
	end	

	LogTraceLocal ('RET132: Response from urlGET Current layout request = ' .. kaiDeviceLayout)
end 

function urlGetResponseAllLayout (strError, responseCode, tHeaders, data, context, url)
	local lCount = 1
	table.foreach( data, function()
		layoutInventory[lCount][1] = data[lCount].id
		layoutInventory[lCount][2] = data[lCount].name
		layoutInventory[lCount][3] = data[lCount].group
		lCount = lCount + 1
	end )

	C4:UpdateProperty ('Get Response', 'Get Response : ' .. responseCode)
end 

function urlPostResponse (strError, responseCode, tHeaders, data, context, url)
	C4:UpdateProperty ('Transfer Status', 'POST Response : ' .. responseCode)
end

function urlPutResponseVideo (strError, responseCode, tHeaders, data, context, url)
	C4:UpdateProperty ('Transfer Status', 'PUT Response : ' .. responseCode)
end

function urlPutResponseAudio (strError, responseCode, tHeaders, data, context, url)
	C4:UpdateProperty ('Transfer Status', 'PUT Response : ' .. responseCode)
end

function urlPutResponseP (strError, responseCode, tHeaders, data, context, url)
	C4:UpdateProperty ('Transfer Status', 'PUT Response : ' .. responseCode)
end

function urlGetResponseAudio (strError, responseCode, tHeaders, data, context, url)
	if (data.hdmi_out_stream ~= nil) then	
		g_ActiveAudioIntercept = data.hdmi_out_stream
		 LogTraceLocal ('RET573: URL Kai New Audio source = ' .. g_ActiveAudioIntercept )
	else LogTraceLocal ('WRN573: URL Kai New Audio source = NULL')
	end	
end

function urlDeleteResponse (strError, responseCode, tHeaders, data, context, url)
	C4:UpdateProperty ('Transfer Status', 'DELETE response state : ' .. responseCode)
end

--[[=============================================================================
Remove all non ascii characters
===============================================================================]]
function stripControlCodes( str )
    local s = ""
    for i = 1, str:len() do
	if str:byte(i) >= 32 and str:byte(i) <= 126 then
  	    s = s .. str:sub(i,i)
	end
    end
    return s
end
--[[=============================================================================
display the trace buffer.
===============================================================================]]
function displayTrace()
	print(g_TraceBuffer) -- Use this to view lua log during loading.
end

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

require "c4_log"
require "c4_common"
require "constants"

--[[=============================================================================

===============================================================================]]
function WSMakeHeaders ()
	LogTraceLocal ('MSG231: Entering WSMakeHeaders ()')
	local head = {}
	table.insert (head, 'GET ' .. WS.RESOURCE .. ' HTTP/1.1')
	table.insert (head, 'Host: ' .. WS.HOST .. ':' .. WS.PORT)
	table.insert (head, 'Cache-Control: no-cache')
	table.insert (head, 'Pragma: no-cache')
	table.insert (head, 'Connection: Upgrade')
	table.insert (head, 'Upgrade: websocket')
	-- Sec-WebSocket-Key is random 16-byte value, base64 encoded...
	WS.KEY = ''
	for i = 1, 16 do
		WS.KEY = WS.KEY .. string.char (math.random (33, 125))
	end
	WS.KEY = C4:Base64Encode (WS.KEY)
	table.insert (head, 'Sec-WebSocket-Key: ' .. WS.KEY)
	table.insert (head, 'Sec-WebSocket-Version: 13')
	table.insert (head, 'User-Agent: C4WebSocketDemo/1')
	table.insert (head, '\r\n')
	return (table.concat (head, '\r\n'))
end
--[[=============================================================================

===============================================================================]]
function WSStart (url)
	LogTraceLocal ('MSG702: WSStart(), Starting Web Socket... Creating net connection to ' .. url)

	local protocol, rest = string.match (url, '(wss?)://(.*)')
	if (not (protocol and rest)) then
		printLocal ('ERR203: invalid websocket URL provided = [' .. url .. ']')
		return
	end

	local hostport, resource = string.match (rest, '(.-)(/.*)')
	if (not (hostport and resource)) then
		hostport = rest
		resource = '/'
	end

	local host, port = string.match (hostport, '(.-):(.*)')
	
	if (not (host and port)) then
		host = hostport
		if (protocol == 'ws') then port = 80
		elseif (protocol == 'wss') then port = 443
		end
		LogTraceLocal ('MSG200: WSStart() Port setup, Host = ' .. host .. ' Port = ' .. port)
	end

	port = tonumber (port)

	if (protocol and host and port and resource) then
		WS.PING_INTERVAL = 30
		WS.PROTOCOL = protocol
		WS.HOST = host
		WS.PORT = port
		WS.RESOURCE = resource
		WS.BUF = ''
		if (protocol == 'wss') then
			C4:CreateNetworkConnection (6001, WS.HOST, 'SSL') -- WebSockets connection...
			C4:NetPortOptions (6001, WS.PORT, 'SSL', {verify_mode = 'peer', verify_method = 'tlsv1'})
		else
			C4:CreateNetworkConnection (6001, WS.HOST) -- WebSockets connection...
		end
		C4:NetDisconnect (6001, WS.PORT)
		C4:NetConnect (6001, WS.PORT)
	end
end
--[[=============================================================================

===============================================================================]]
function WSParsePacket (strData)
	WS.BUF = (WS.BUF or '') .. strData

	if (WS.RUNNING) then
		LogTraceLocal ('MSG845: WSParsePacket() is running. Processing socket data.')
		local _, h1, h2, b1, b2, b3, b4, b5, b6, b7, b8 = string.unpack (WS.BUF, 'bbbbbbbbbb')

		local final = (bit.band (h1, 0x80) == 0x80)
		local rsv1 = (bit.band (h1, 0x40) == 0x40)
		local rsv2 = (bit.band (h1, 0x20) == 0x20)
		local rsv3 = (bit.band (h1, 0x10) == 0x10)
		local opcode = bit.band (h1, 0x0F)

		local masked = (bit.band (h2, 0x80) == 0x80)
		local mask
		local len = bit.band (h2, 0x7F)

		local msglen = 0
		local headerlen = 2
		if (len <= 125) then
			-- 1-byte length
			msglen = len
		elseif (len == 126) then
			-- 2-byte length
			msglen = msglen + b1; msglen = msglen * 0x100
			msglen = msglen + b2;
			headerlen = 4
		elseif (len == 127) then
			-- 8-byte length
			msglen = msglen + b1; msglen = msglen * 0x100
			msglen = msglen + b2; msglen = msglen * 0x100
			msglen = msglen + b3; msglen = msglen * 0x100
			msglen = msglen + b4; msglen = msglen * 0x100
			msglen = msglen + b5; msglen = msglen * 0x100
			msglen = msglen + b6; msglen = msglen * 0x100
			msglen = msglen + b7; msglen = msglen * 0x100
			msglen = msglen + b8;
			headerlen = 10
		end

		if (masked) then
			local maskbytes = string.sub (WS.BUF, headerlen + 1, headerlen + 5)
			mask = {}
			for i = 1, 4 do
				mask [i] = string.byte (string.sub (maskbytes, i, i))
			end
			headerlen = headerlen + 4
		end

		if (string.len (WS.BUF) >= headerlen + msglen) then
			local thisFragment = string.sub (WS.BUF, headerlen + 1, headerlen + msglen)
			if (masked) then
				if (mask) then
					thisFragment = WSMask (thisFragment, mask)
				else
					printLocal ('ERR244: masked bit set but no mask received')
					WS.BUF = ''
					return
				end
			end
			WS.BUF = string.sub (WS.BUF, headerlen + msglen + 1)

			if (opcode == 0x08) then -- connection close control frame
				-- WS.LIBRARY - make callback for WS.CLOSED_BY_REMOTE

			elseif (opcode == 0x09) then -- ping control frame
				WSPong ()

			elseif (opcode == 0x0A) then -- pong control frame

			elseif (opcode == 0x00) then -- continuation frame
				if (not WS.FRAGMENT) then
					WS.BUF = ''
					return
				end
				WS.FRAGMENT = WS.FRAGMENT .. thisFragment

			elseif (opcode == 0x01 or opcode == 0x02) then -- non-control frame, beginning of fragment
				WS.FRAGMENT = thisFragment
			end

			if (final and opcode < 0x08) then
				local data = WS.FRAGMENT
				WS.FRAGMENT = nil

				WSProcessMessage (data)
			end

			if (string.len (WS.BUF) > 0) then
				WSParsePacket ('')
			end

		end

		return
	else
		--LogTraceLocal ('MSG865: WSParsePacket() is stopped. Continuing...')
	end

	local headers = {}
	for line in string.gmatch (strData, '(.-)\r\n') do
		local k, v = string.match (line, '%s*(.-)%s*[:/*]%s*(.+)')
		if (k and v) then
			k = string.upper (k)
			headers [k] = v
		end
	end

	local EOH = string.find (WS.BUF, '\r\n\r\n')

	if (EOH and headers ['SEC-WEBSOCKET-ACCEPT']) then
		WS.BUF = string.sub (WS.BUF, EOH + 4)
		local check = WS.KEY .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
		local hash = C4:Hash ('sha1', check, {['return_encoding'] = 'BASE64'})

		LogTraceLocal ('MSG202: WebSocket connection accepted. HTTP Header looks fine.')

		if (headers ['SEC-WEBSOCKET-ACCEPT'] == hash and
			headers ['CONNECTION'] == 'Upgrade' and
			headers ['UPGRADE'] == 'websocket') then

			g_HttpHeaderCnt = g_HttpHeaderCnt + 1

			WS.RUNNING = true
			LogTraceLocal ('MSG208: WebSocket connection established. Ready to receive websocket data packets.')
			-- WS.LIBRARY - make callback for WS.ESTABLISHED
		end
	end
end
--[[=============================================================================

===============================================================================]]
function WSClose ()
	LogTraceLocal ('MSG232: Entering WSClose ()')
	WS.RUNNING = false
	if (not (WS.CONNECTED)) then LogTraceLocal ('MSG209: Websocket disconnected, nothing to close') return end

	local pkt = string.char (0x88, 0x82, 0x00, 0x00, 0x00, 0x00, 0x03, 0xE8)
	C4:SendToNetwork (6001, WS.PORT, pkt)
end
--[[=============================================================================

===============================================================================]]
function WSPing ()
	if (not (WS.CONNECTED)) then LogTraceLocal ('MSG210: Websocket disconnected, no reason to ping') return end
	-- MASK of 0x00's
	local pkt = string.char (0x89, 0x80, 0x00, 0x00, 0x00, 0x00)
	C4:SendToNetwork (6001, WS.PORT, pkt)
end
--[[=============================================================================

===============================================================================]]
function WSPong ()
	if (not (WS.CONNECTED)) then LogTraceLocal ('MSG211:  Websocket disconnected, no reason to pong') return end
	-- MASK of 0x00's
	local pkt = string.char (0x8A, 0x80, 0x00, 0x00, 0x00, 0x00)
	C4:SendToNetwork (6001, WS.PORT, pkt)
end
--[[=============================================================================

===============================================================================]]
function WSSend (s)
	LogTraceLocal ('MSG233: Entering WSSend () = ' .. s)
	if (not (WS.CONNECTED)) then 
		LogTraceLocal ('MSG212: WSSend, Websocket disconnected, not sending data') 
		return 
	end

	local len = string.len (s)
	local lenstr = ''
	if (len <= 125) then
		lenstr = string.char (0x81, bit.bor (len, 0x80))
	elseif (len <= 65535) then
		lenstr = string.char (0x81, bit.bor (126, 0x80)) .. tohex (string.format ('%04X', len))
	else
		lenstr = string.char (0x81, bit.bor (127, 0x80)) .. tohex (string.format ('%16X', len))
	end

	local mask = {math.random (0, 255), math.random (0, 255), math.random (0, 255), math.random (0, 255)}
	local packet = {lenstr, string.char (mask [1]), string.char (mask [2]), string.char (mask [3]), string.char (mask [4])}

	table.insert (packet, WSMask (s, mask))

	packet = table.concat (packet)

	LogTraceLocal ('MSG288: Sending Packet = ' .. packet)
	C4:SendToNetwork(6001, WS.PORT, packet)
end
--[[=============================================================================

===============================================================================]]
function WSMask (s, mask)
	LogTraceLocal ('MSG234: Entering WSMask ()')
	if (type (mask) == 'table') then
	elseif (type (mask) == 'string' and string.len (mask) >= 4) then
		local m = {}
		for i = 1, string.len (mask) do
			table.insert (m, string.byte (mask [i]))
		end
		mask = m
	end

	local slen = string.len (s)
	local mlen = table.getn (mask)

	local packet = {}

	for i = 1, slen do
		local pos = i % mlen
		if (pos == 0) then pos = mlen end
		local maskbyte = mask [pos]
		local sbyte = string.sub (s, i, i)
		local byte = string.byte (sbyte)
		local char = string.char (bit.bxor (byte, maskbyte))
		table.insert (packet, char)
	end

	packet = table.concat (packet)
	return (packet)
end
--[[=============================================================================

===============================================================================]]
function WSProcessMessage (data)
	LogTraceLocal('RSP444: Websocket Process Message = ' .. data)
	decodeResponsePacket(data)
end
--[[=============================================================================

===============================================================================]]
function decodeResponsePacket(data)
	local myPort = 0
	local channelCount = 0

	LogTraceLocal('RSP666: decodeResponsePacket() = ' .. data)
--*****************************************************************************************************
-- Find  response string that contains "layout_will_load"
--*****************************************************************************************************
	if(string.find (data, "layout_will_load")) then
		g_LayoutLoadingCnt = g_LayoutLoadingCnt + 1

		LogTraceLocal( 'RSP528: Websocket Layout Will Load Packet')

		local layoutWillLoad = JSON:decode( data ) 

		local channelCount = 0
		table.foreach( layoutWillLoad.layout.windows, function() channelCount = channelCount + 1 end )

		-- Start out with all 4 channel cleared out.
		for y = g_MinInputs, g_MaxInputs do
			hdmiInput[y][4] = 0
			hdmiInput[y][5] = 'None'
		end	

		g_WebSockLayoutLoaded = layoutWillLoad.layout.id  
		LogTraceLocal( 'RSP472: Websocket Layout ID = ' .. g_LayoutChangeId)

		g_WebSockLayoutLoadedName = layoutWillLoad.layout.name 
		LogTraceLocal( 'RSP473: Websocket Layout Name = ' .. g_WebSockLayoutLoadedName)

		LogTraceLocal('RSP499: LAYOUT_WILL_LOAD Channel numbers to change = ' .. channelCount)
		g_WebsocketInputsLoaded = channelCount

		-- If we have one channel to load, start parsing the rest of this string.
		if(channelCount == 1) then

			myPort = layoutWillLoad.layout.windows[1].hdmi_properties.port 
			if(myPort ~= nil) then
				g_ActiveAudioIntercept = myPort

				-- Change audio to this new port
				g_AudioChangePort  = myPort
				audioChange ()
				
				g_WebsocketPortLoaded = myPort
				sendKeyboardChar(KBD_A)
				LogTraceLocal ('RSP773: Websocket port number was detected = ' .. myPort)	

				sendChannelChange (hdmiInput[myPort][4],myPort)

			else
				printLocal ('ERR773: Websocket port number was detected as NULL.')	
			end
		-- If we have multiple channels to load, start parsing the rest of this string.
		elseif (channelCount > 1) then

			g_WebsocketPortLoaded = MULTIPLE_INPUTS

			-- How many windows are in this layout?
			for y = 1, channelCount do

				LogTraceLocal ('RSP443: Layout Will Load window count = ' .. channelCount)	

				-- Which port?
				myPort = layoutWillLoad.layout.windows[y].hdmi_properties.port 
				if(myPort ~= nil) then

					-- Load the channel number into the hdmi router.
					hdmiInput[myPort][4] = layoutWillLoad.layout.windows[y].hdmi_properties.tuner_channel

					-- Load the channel names into the hdmi router.
					hdmiInput[myPort][5] = layoutWillLoad.layout.windows[y].hdmi_properties.tuner_channel_name 
				end	
				sendChannelChange (hdmiInput[myPort][4],myPort)	-- Change the hdmi port if applicable 
			end	
		else
			printLocal ('ERR443: Websocket received a "layout_will_load" packet, but no channel info found. channelCount = ' .. channelCount)
			printLocal ('        Could be an old layout format??')
		end	
--*****************************************************************************************************
-- Find  response string that contains "layout_loaded"
--*****************************************************************************************************
	elseif(string.find (data, "layout_loaded")) then
		g_LayoutLoadedCnt = g_LayoutLoadedCnt + 1
		LogTraceLocal( 'RSP578: Websocket Layout Loaded Packet')

		local layoutLoaded = JSON:decode( data )

		g_WebSockLayoutLoaded = layoutLoaded.layout_id  
		LogTraceLocal( 'RSP572: Websocket Layout ID = ' .. g_WebSockLayoutLoaded)

		g_PrevLayoutOld = g_PrevLayoutNew 
		LogTraceLocal('MSG500: Updating OLD layout ' .. g_PrevLayoutOld)

		g_PrevLayoutNew  = layoutLoaded.layout_id  
		LogTraceLocal('MSG503: Updating NEW layout ' .. g_PrevLayoutNew)

		g_WebSockLayoutLoadedName = layoutLoaded.layout_name 
		LogTraceLocal( 'RSP573: Websocket Layout Name = ' .. g_WebSockLayoutLoadedName)
	
--*****************************************************************************************************
-- Find  response string that contains "audio_configuration" and look for currentlayout ID.
--*****************************************************************************************************
	elseif(string.find (data, "audio_configuration")) then
		g_AudioConfigCnt = g_AudioConfigCnt + 1

		-- Start out with all 4 ports cleared out.
		for j =g_MinInputs, g_MaxInputs do
			g_PagePorts[j] = 0
		end	

		-- Check the state of the windows and ports in use.
		local audioConfiguration = JSON:decode( data )
		local pageIndex = 1
		for y = g_MinInputs, g_MaxInputs do
			g_WindowState[y] = tostring(audioConfiguration.hdmi_ports[y].in_use)
			g_PortSignal[y] = tostring(audioConfiguration.hdmi_ports[y].has_signal)
			g_PortNumber[y] = tostring(audioConfiguration.hdmi_ports[y].port)
			g_PortName[y] = tostring(audioConfiguration.hdmi_ports[y].device_name)
			LogTraceLocal('RSP992: IDX = ' .. y .. ' PORT = ' .. g_PortNumber[y] .. ' NAME = ' .. g_PortName[y] .. ' In Use = ' .. g_WindowState[y] .. ' Signal = ' .. g_PortSignal[y] ) 
			if(g_PortSignal[y] == "true") then 
				g_PagePorts[pageIndex] = g_PortNumber[y]
				LogTraceLocal('RSP991: IDX = ' .. pageIndex .. ' page Port = ' .. g_PagePorts[pageIndex] ) 
				pageIndex = pageIndex + 1
			end	
		end
		LogTraceLocal('RSP997: page Index = ' .. pageIndex ) 
		
		-- Sometimes the "currently_loaded_layout" section return null, so check for it.
		if(audioConfiguration.window_manager.currently_loaded_layout ~= nil) then
			local currentId = audioConfiguration.window_manager.currently_loaded_layout.id
			local currentName = audioConfiguration.window_manager.currently_loaded_layout.name
			LogTraceLocal('RSP952: Currently loaded ID and = ' .. currentId .. ' Name = ' .. currentName ) 

			local winCount = 0
			table.foreach( audioConfiguration.window_manager.currently_loaded_layout.windows, function() winCount = winCount + 1 end )
			LogTraceLocal('MSG620: Window Count = ' .. tonumber(winCount))
		else
			LogTraceLocal('RSP953: Currently loaded Layout and ID are = null') 
		end

		g_ActiveAudioIntercept = audioConfiguration.audio_mixer_config.hdmi_out_stream
		LogTraceLocal('RSP592: Audio Configuration Intercept port = ' .. g_ActiveAudioIntercept)

		-- Check for ports in use
		local _, inUse = string.gsub(data, '"in_use":true', "")
		LogTraceLocal('RSP453: HDMI Ports in use found = ' .. inUse)
		g_PortsInUse = inUse

		-- Check for signal found
		local _, hasSignal = string.gsub(data, '"has_signal":true', "")
		LogTraceLocal('RSP454: HDMI Ports with a signal found = ' .. hasSignal)
		g_SignalFound = hasSignal
--*****************************************************************************************************
-- Find  response string that contains "audio_mixer_configuration" and look for output stream.
--*****************************************************************************************************
	elseif(string.find (data, '"audio_mixer_configuration":')) then
		g_AudioMixerCnt = g_AudioMixerCnt + 1

		local audioMixerConfiguration = JSON:decode( data )
 
		g_ActiveAudioIntercept = audioMixerConfiguration.audio_mixer_configuration.hdmi_out_stream 
		LogTraceLocal('RSP593: Audio Mixer Configuration Intercept port = ' .. g_ActiveAudioIntercept )
--*****************************************************************************************************
-- Packet string not used by this driver.
--*****************************************************************************************************
	else
		-- truncate 
		local msgLength = string.len(data)
		if(msgLength ~= nil and msgLength > 40) then
			local myString = string.sub(data, 0, 40)
			LogTraceLocal('WRN667: Driver does not need this packet = ' .. myString .. ' Truncated....')
		else
			LogTraceLocal('ERR667: Driver decode packet error.')
		end	
	end	
end

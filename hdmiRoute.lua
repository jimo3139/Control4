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

require "utils"
require "constants"

-- Not PID = Proxy ID, and DID = Display ID.
hdmiInput = {}
-- Input		PID		DID	  Device   channel  program
hdmiInput[1]  = {0,		0,	'detached',	0,		'None'}
hdmiInput[2]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[3]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[4]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[5]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[6]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[7]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[8]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[9]  = {0,		0,	'detached', 0,		'None'}
hdmiInput[10] = {0,		0,	'detached', 0,		'None'}
hdmiInput[11] = {0,		0,	'detached', 0,		'None'}
hdmiInput[12] = {0,		0,	'detached', 0,		'None'}
hdmiInput[13] = {0,		0,	'detached', 0,		'None'}
hdmiInput[14] = {0,		0,	'detached', 0,		'None'}
hdmiInput[15] = {0,		0,	'detached', 0,		'None'}
hdmiInput[16] = {0,		0,	'detached', 0,		'None'}

--[[=============================================================================
Send a message to the HDMI 1 layout.
===============================================================================]]
function sendMessageHdmi1 (msg)
	local kaiIpPrim = Properties ['Static IP Address']
	local repCount = 1
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}
	local port = 1

	-- Set the port name in the Kai unit.
	local layoutPort = '{"device_name": "(' .. msg .. ') "}'
	local kaiNamePort = kaiIpPrim .. "/1/hdmi-ports/" .. port
	urlPut (kaiNamePort, layoutPort, headers, urlPutResponseP, {repCount = repCount})
	LogTraceLocal ('MSG721: Set Name, Port = ' .. kaiNamePort .. ' String = ' .. layoutPort)
end
--[[=============================================================================
Build the HDMI router table
===============================================================================]]
function buildRouteTable ()
	local kaiIpPrim = Properties ['Static IP Address']
	local repCount = 1
	local headers = {['Content-Type'] = 'application/json', ['Accept'] = 'application/json'}

	clearRouteTable ()
	LogTraceLocal ('MSG520: Building a new HDMI Router table.')
	local proxyNumber = 0
	local avs_proxy_id, skreens_MP_proxy_id = C4:GetProxyDevices ()

	for y = g_MinInputs, g_MaxInputs do
		hdmiInput[y][1] = C4:GetBoundProviderDevice (avs_proxy_id, 1000 + y)
		hdmiInput[y][2] = C4:GetBoundProviderDevice (skreens_MP_proxy_id, 1000 + y)
		proxyNumber = tonumber(hdmiInput[y][1])

		if (hdmiInput[y][1] ~= 0) then 
			hdmiInput[y][3] = C4:ListGetDeviceName(proxyNumber) 
	
			-- for SET_INPUT commands from other devices, determine which ones got to FULL screen
			if(hdmiInput[y][3] == 'EA-') then	hdmiInput[y][2] = 'HOLD'
			else								hdmiInput[y][2] = 'FULL'
			end	

			-- Set the port name in the Kai unit.
			local layoutPort = '{"device_name": "(' .. hdmiInput[y][3] .. ') "}'
			local kaiNamePort = kaiIpPrim .. "/1/hdmi-ports/" .. y
			urlPut (kaiNamePort, layoutPort, headers, urlPutResponseP, {repCount = repCount})
			LogTraceLocal ('MSG521: Set Name, Port = ' .. kaiNamePort .. ' String = ' .. layoutPort)

			g_AttachedDevices = g_AttachedDevices + 1
		end	
		hdmiInput[y][4] = 0
		hdmiInput[y][5] = 'None'
	end
end
--[[=============================================================================
Scan for proxy Ids for device names.
===============================================================================]]
function scanDirectorDevices ()
	local packet = "[{"
	local flag = 0
	local maxScan = 2000
	local avs_proxy_id, skreens_MP_proxy_id = C4:GetProxyDevices ()

	for y = 1, maxScan do
		local myDevName = C4:ListGetDeviceName(y)
		local len = string.len(myDevName)
		if(len ~= 0) then

			if(flag == 0) then flag = 1
			else packet = packet .. ", "
			end	

			local proxyNumber = string.format( "%04d", y )
			--printLocal ('MSG111: Proxy ID = ' .. proxyNumber .. ' Name = ' .. myDevName)

			packet = packet .. '"' .. proxyNumber .. '": "' .. myDevName .. '"'

		end	
	end

	packet = packet .. "}]"
	sendProxyInventory (packet)
	--print(packet)
end
--[[=============================================================================
Search for proxy Ids for device names.
===============================================================================]]
function searchRouteTable (proxyName)
	local proxyNumber = 0
	local maxScan = 1000
	local avs_proxy_id, skreens_MP_proxy_id = C4:GetProxyDevices ()

	for y = 1, maxScan do
		local myDevName = C4:ListGetDeviceName(y)
		local len = string.len(myDevName)
		if(len ~= 0) then
			if(myDevName == proxyName) then
				proxyNumber = string.format( "%04d", y )
				return proxyNumber
			end	
		end	
	end
	return proxyNumber
end
--[[=============================================================================
Display the HDMI router table
===============================================================================]]
function displayRouteTable ()
	for y = g_MinInputs, g_MaxInputs do
		for x = 1, 5 do
			-- print ('Field ' .. hdmiInput[y][x])
		end
		print('HDMI Input [' .. y .. '] PID [' .. hdmiInput[y][1] .. '] DID [' .. hdmiInput[y][2] .. '] Device [' .. hdmiInput[y][3] .. '] Channel [' .. hdmiInput[y][4] .. '] Program [' .. hdmiInput[y][5] .. ']')
	end
end
--[[=============================================================================
Clear the HDMI router table
===============================================================================]]
function clearRouteTable ()
	LogTraceLocal ('MSG519: Clearing HDMI Router table.')
	for y = g_MinInputs, g_MaxInputs do
		hdmiInput[y] = {0,		0,	'detached'}
	end
end
--[[=============================================================================
Route this new device to the appropiate HDMI input on the Kai unit.
===============================================================================]]
function deviceRouteNew (newInput)
	LogTraceLocal ('MSG595: deviceRouteNew() New Video and Audio HDML input = ' .. newInput)
	g_LayoutChangeId = newInput
	layoutChange ()
end

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
** Default variables **********************************************************************]]
MULTIPLE_INPUTS		= 99
MIN_KAI_INPUTS		= 1
MAX_KAI_INPUTS4		= 4
MAX_KAI_INPUTS16	= 16
DISPLAY_ALL			= 5
TIMER_IDLE			= 0 
TIMER_ACTIVE		= 1
MAX_FILE_SIZE		= 20480 -- 20k bytes
TRACE_FILENAME		= 'skreens.trc'
INTERCEPT_OFF		= 0
INTERCEPT_ON		= 1 
SHOW_ONE			= 'ONE'
SHOW_TWO			= 'TWO'
SHOW_OLD			= 'OLD'
SHOW_NEW			= 'NEW'
DISCOVER_AUTO		= 0
DISCOVER_ALL		= 1
TIMER_CANCEL		= 1 
TIMER_STOP			= 2 
--** Config options *********************
CFG_NONE			= 'off'
CFG_TIMER			= 'timeout'
CFG_INTERCEPT		= 'intercept'
CFG_TIMER_ON		= 'enabled'
CFG_TIMER_OFF		= 'disabled'
--** OSD options *********************
OSD_OFF				= 'off'
OSD_LAYOUTS			= 'layouts'
OSD_MENU			= 'menu'
OSD_HELP			= 'help'
OSD_HOME			= 'home'
OSD_STATUS			= 'status'
--** SWAP options *********************
SWAP_OFF			= 'off'
SWAP_ON				= 'on'
--** PINGPONG options *********************
PINGPONG_OFF		= 'off'
PINGPONG_ON			= 'on'
--** Packet Header options *********************
PACK_TYPE_81		= 129
PACK_TYPE_1			= 1
PACK_FUNCTION		= 126
PACK_SMALL			= 0
PACK_PING			= 137
PACK_TERM			= 138
PACK_NULL			= 0
--** Supported values for the 'control_character' field *********************
CHAR_BACKSPACE	= 'backspace'
CHAR_DELETE		= 'delete'
CHAR_TAB		= 'tab'
CHAR_RETURN		= 'return'
CHAR_HOME		= 'home'
CHAR_END		= 'end'
CHAR_LEFT		= 'left'
CHAR_RIGHT		= 'right'
CHAR_DOWN		= 'down'
CHAR_UP			= 'up' 
CHAR_PAGEUP		= 'pageup'
CHAR_PAGEDOWN	= 'pagedown'
CHAR_ONE		= '1'
--** Keyboard tokens *********************
KBD_F			= "f"	-- full screen
KBD_A			= "a"	-- select audio
KBD_X			= "x"	-- select Right with Audio
KBD_Z			= "z"	-- select Left with Audio
--** Keystrokes that get sent to a device *********************
Tx_On			= "ON"
Tx_Off			= "OFF"
Tx_MuteOn		= "MUTE_ON"
Tx_MuteOff		= "MUTE_OFF"
Tx_MuteTog		= "MUTE_TOGGLE"
Tx_Input		= "INPUT_TOGGLE"
Tx_Num0			= "NUMBER_0"
Tx_Num1			= "NUMBER_1"
Tx_Num2			= "NUMBER_2"
Tx_Num3			= "NUMBER_3" 
Tx_Num4			= "NUMBER_4"
Tx_Num5			= "NUMBER_5"
Tx_Num6			= "NUMBER_6"
Tx_Num7			= "NUMBER_7"
Tx_Num8			= "NUMBER_8"
Tx_Num9			= "NUMBER_9"
Tx_PulseVup		= "PULSE_VOL_UP"
Tx_PulseVdn		= "PULSE_VOL_DOWN"
Tx_Menu			= "MENU"
Tx_Enter		= "ENTER"
Tx_Up			= "UP"
Tx_Down			= "DOWN"
Tx_Left			= "LEFT"
Tx_Right		= "RIGHT"
Tx_Cancel		= "CANCEL"
--** Keystrokes that are local to cintrol the Kai ******************************
Loc_Custom1		= "CUSTOM_1"
Loc_Custom2		= "CUSTOM_2"
Loc_Custom3		= "CUSTOM_3"
Loc_PageUp		= "PAGE_UP"
Loc_PageDown	= "PAGE_DOWN"
Loc_Star		= "STAR"
Loc_Pound		= "POUND"
Loc_Info		= "INFO"
Loc_Prev		= "RECALL"
Loc_Guide		= "GUIDE"
Loc_Red			= "PROGRAM_A"
Loc_Green		= "PROGRAM_B"
Loc_Yellow		= "PROGRAM_C"
Loc_Blue		= "PROGRAM_D"
--** Async response control definitions *************************************************
ASYNC_NONE		= '0'
ASYNC_ID_SCAN	= '1'


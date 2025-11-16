;#SingleInstance

#Include "WinGetPosEx.ahk"

TraySetIcon(A_ScriptDir . "\winfix.ico")



;/********************************\
; * Select Virtual Desktop Logic * 
;\********************************/

DetectHiddenWindows(true)
hwnd:=WinExist("ahk_pid " . DllCall("GetCurrentProcessId", "Uint"))
hwnd+=0x1000<<32

; this dll provides a base pointer to the desired virtual desktop api
hVirtualDesktopAccessor := DllCall("LoadLibrary", "Str", (A_ScriptDir . "\VirtualDesktopAccessor.dll"), "Ptr")

; the windows virtual desktop api
GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GoToDesktopNumber", "Ptr")
GetCurrentDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GetCurrentDesktopNumber", "Ptr")
IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "IsWindowOnCurrentVirtualDesktop", "Ptr")
MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "MoveWindowToDesktopNumber", "Ptr")
RegisterPostMessageHookProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "RegisterPostMessageHook", "Ptr")
UnregisterPostMessageHookProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "UnregisterPostMessageHook", "Ptr")
IsPinnedWindowProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "IsPinnedWindow", "Ptr")
RestartVirtualDesktopAccessorProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "RestartVirtualDesktopAccessor", "Ptr")
; GetWindowDesktopNumberProc := DllCall("GetProcAddress", Ptr, hVirtualDesktopAccessor, AStr, "GetWindowDesktopNumber", "Ptr")

; Restart the virtual desktop accessor when Explorer.exe crashes, or restarts (e.g. when coming from fullscreen game)
explorerRestartMsg := DllCall("user32\RegisterWindowMessage", "Str", "TaskbarCreated")
OnMessage(explorerRestartMsg, OnExplorerRestart)
OnExplorerRestart(wParam, lParam, msg, hwnd) {
    global RestartVirtualDesktopAccessorProc
	result := 0
    DllCall(RestartVirtualDesktopAccessorProc, "UInt", result)
}

; Move a window between desktops
MoveCurrentWindowToDesktop(num) {
	global GetCurrentDesktopNumberProc, MoveWindowToDesktopNumberProc, GoToDesktopNumberProc

	current := DllCall(GetCurrentDesktopNumberProc, "UInt") 
	next := current+num
	
	; Ensure that we wont move out of our 3x3 grid
	if(next < 0 || next >= 9 || (1 == Abs(num) && Floor(current/3) != Floor(next/3))){
		return
	}
	
	activeHwnd := WinGetID("A")
	DllCall(MoveWindowToDesktopNumberProc, "UInt", activeHwnd, "UInt", next)
	
	DllCall(GoToDesktopNumberProc, "UInt", next)
}

; Move between desktops without a window
GoToDesktopNumber(num) {
	global GetCurrentDesktopNumberProc, GoToDesktopNumberProc

	current := DllCall(GetCurrentDesktopNumberProc, "UInt")
	next := current+num
	
	; Ensure that we wont move out of our 3x3 grid
	if(next < 0 || next >= 9 || (1 == Abs(num) && Floor(current/3) != Floor(next/3))){
		return
	}

	; Change desktop
	DllCall(GoToDesktopNumberProc, "Int", next)
	
	; select a window
	; note: sleep wont fix that sometimes a window will be selected that's not on the current workspace
	; note: I'd rather select no window at all then having to deal with text going to random other windows
	; Send {AltTab}
}

; Windows 10 desktop changes listener
DllCall(RegisterPostMessageHookProc, "Int", hwnd, "Int", 0x1400 + 30)
OnMessage(0x1400 + 30, VWMess)
VWMess(wParam, lParam, msg, hwnd) {
	global activeWindowByDesktop, desktopNumber

	desktopNumber := lParam + 1
	
	; Update tray icon
	TraySetIcon(A_ScriptDir . "\winfix" . lParam . ".ico")
}

; Open terminal

^+A::
{
Run("`"C:\Program Files\Git\git-bash.exe`"", EnvGet("HOMEPATH"))
return
}

;/*************************\
; *   Fix Movement Keys   *
;\*************************/

;Note: We make 9 workspaces and let up/down movement move by 3. This is not entirely correct, but acceptable for now.

^!Left::
{
GoToDesktopNumber(-1)
return
}

^!Up::
{
GoToDesktopNumber(-3)
return
}

^!Right::
{
GoToDesktopNumber( 1)
return
}

^!Down::
{
GoToDesktopNumber( 3)
return
}

;/*********************************\
; *   Window-Grab Movement Keys   *
;\*********************************/

^!+Left::
{
MoveCurrentWindowToDesktop(-1)
return
}

^!+Up::
{
MoveCurrentWindowToDesktop(-3)
return
}

^!+Right::
{
MoveCurrentWindowToDesktop( 1)
return
}

^!+Down::
{
MoveCurrentWindowToDesktop( 3)
return
}


;/**************************\
; *   Window-Tiling Keys   *
;\**************************/


PlaceTo(X, Y, W, H) {
	; note: the offset correction is required as a workaround for DWM reporting window sizes incorrectly
	; note: the reported sizes are still off by 1 as there is a 1 pixel border for selection that disappears when loosing focus
	; also, that border does not make sense for fullscreen windows
	WinGetOffsets("A", &L, &T, &R, &B)
	X := X - L - 1
	Y := Y - T - 1
	W := W + L + R + 2
	H := H + T + B + 2
	WinMove(X, Y, W, H, "A")
	return
}


^!Numpad7::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)/2
H := (MonWABottom-MonWATop)/2
PlaceTo(X, Y, W, H)
return
}

^!Numpad8::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)
H := (MonWABottom-MonWATop)/2
PlaceTo(X, Y, W, H)
return
}

^!Numpad9::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)/2
H := (MonWABottom-MonWATop)/2
X := X + W
PlaceTo(X, Y, W, H)
return
}


^!Numpad4::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)/2
H := (MonWABottom-MonWATop)
PlaceTo(X, Y, W, H)
return
}

^!Numpad5::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)
H := (MonWABottom-MonWATop)
PlaceTo(X, Y, W, H)
return
}

^!Numpad6::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)/2
H := (MonWABottom-MonWATop)
X := X + W
PlaceTo(X, Y, W, H)
return
}


^!Numpad1::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)/2
H := (MonWABottom-MonWATop)/2
Y := Y + H
PlaceTo(X, Y, W, H)
return
}

^!Numpad2::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)
H := (MonWABottom-MonWATop)/2
Y := Y + H
PlaceTo(X, Y, W, H)
return
}

^!Numpad3::
{
MonitorGetWorkArea(, &MonWALeft, &MonWATop, &MonWARight, &MonWABottom)
X := MonWALeft
Y := MonWATop
W := (MonWARight-MonWALeft)/2
H := (MonWABottom-MonWATop)/2
X := X + W
Y := Y + H
PlaceTo(X, Y, W, H)
return
}

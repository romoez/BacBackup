#include-once
#include <WinAPIFiles.au3>
#include <Array.au3>
#include <File.au3>
#include <WinAPIFiles.au3>

Global $UserLocal = _GetUserLocal()
Global Const $FREE_SPACE_DRIVE_BACKUP = 5000 ;en MB

;#########################################################################################

Func DossiersBac($Path = 1) ; 1:Chemins complets, 0:Chemins relatifs
	Local $Bac = _FileListToArray(@HomeDrive, "bac*2*", 2, $Path)
	Local $Liste[1] = [0] ;

	If IsArray($Bac) Then
		$Liste[0] += $Bac[0] ;
		_ArrayDelete($Bac, 0)
		_ArrayAdd($Liste, $Bac) ;
	EndIf
	Return $Liste
EndFunc   ;==>DossiersBac

;#########################################################################################

Func _DossiersTravailEleves($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
	Local $AutresClasses = _FileListToArrayRec(@HomeDrive, "1*;2*;3*;4*;7*;8*;9*;bac*;dc*;ds*", 30, 0, 2, $FullPath + 1)
	Local $Liste[1] = [0] ;


	If IsArray($AutresClasses) Then
		$Liste[0] += $AutresClasses[0] ;
		_ArrayDelete($AutresClasses, 0)
		_ArrayAdd($Liste, $AutresClasses) ;
	EndIf
	Return $Liste
EndFunc   ;==>_DossiersTravailEleves

;#########################################################################################

Func _DossiersSurBureau($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
	Local $AutresClasses = _FileListToArrayRec(@DesktopDir, "1*;2*;3*;4*;7*;8*;9*;bac*;dc*;ds*", 30, 0, 2, $FullPath + 1)
	Local $Liste[1] = [0] ;
	If IsArray($AutresClasses) Then
		$Liste[0] += $AutresClasses[0] ;
		_ArrayDelete($AutresClasses, 0)
		_ArrayAdd($Liste, $AutresClasses) ;
	EndIf
	Return $Liste
EndFunc   ;==>_DossiersSurBureau

;#########################################################################################

Func LecteurSauvegarde()
	Local $aDrive = DriveGetDrive('FIXED')
	$Lecteur = @HomeDrive ; "C:" ; $aDrive[1] ; $aDrive[1] peut être A: !!
	For $i = 1 To $aDrive[0]
		If $aDrive[$i] = @HomeDrive Then ContinueLoop
		If (DriveGetType($aDrive[$i], $DT_BUSTYPE) <> "USB") _ ; pour Exclure les hdd externes
				And _WinAPI_IsWritable($aDrive[$i]) _
				And DriveSpaceFree($aDrive[$i] & "\") > $FREE_SPACE_DRIVE_BACKUP _ ;1Go
				Then
			$Lecteur = $aDrive[$i]
			ExitLoop
		EndIf
	Next
	$Lecteur = $Lecteur & "\"
	Return $Lecteur
EndFunc   ;==>LecteurSauvegarde

;#########################################################################################

Func _IntervalleInterSauvegardesEnMinutes()
	Local $IntervalleInterSauvegardes = IniRead($UserLocal & "\BacBackup\BacBackup.ini", "Params", "Intervalle", "")
	If StringIsInt($IntervalleInterSauvegardes) = 0 Or $IntervalleInterSauvegardes < 1 Or $IntervalleInterSauvegardes > 15 Then
		$IntervalleInterSauvegardes = 2 ;2 Minutes
		IniWrite($UserLocal & "\BacBackup\BacBackup.ini", "Params", "Intervalle", $IntervalleInterSauvegardes)
	EndIf
	Return $IntervalleInterSauvegardes
EndFunc   ;==>_IntervalleInterSauvegardesEnMinutes

;#########################################################################################

Func DossiersTPW($Path = 1) ; 1:Chemins complets, 0:Chemins relatifs
	Local $TPW = _FileListToArray(@HomeDrive, "TPW*", 2, $Path)
	Local $Liste[1] = [0] ;

	If IsArray($TPW) Then
		$Liste[0] += $TPW[0] ;
		_ArrayDelete($TPW, 0)
		_ArrayAdd($Liste, $TPW) ;
	EndIf
	Return $Liste
EndFunc   ;==>DossiersTPW

;#########################################################################################

Func DossiersEasyPHPwww($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
	Local $aEasyPHP[1] = [0]

	Local $aTmpEasyPHP = _FileListToArrayRec(@HomeDrive, "EasyPHP*;wamp*;xampp*;apachefriends*", 30, 0, 2, $FullPath + 1)

	If IsArray($aTmpEasyPHP) Then
		$aEasyPHP[0] += $aTmpEasyPHP[0]
		_ArrayDelete($aTmpEasyPHP, 0)
		_ArrayAdd($aEasyPHP, $aTmpEasyPHP)
	EndIf

	Local $aTmpEasyPHP = _FileListToArray(@ProgramFilesDir, "EasyPHP*", 2, $FullPath)

	If IsArray($aTmpEasyPHP) Then
		$aEasyPHP[0] += $aTmpEasyPHP[0]
		_ArrayDelete($aTmpEasyPHP, 0)
		_ArrayAdd($aEasyPHP, $aTmpEasyPHP)
	EndIf

	Local $Liste[1] = [0]
	Local $Liste[1] = [0], $www


	If IsArray($aEasyPHP) Then
		For $i = 1 To $aEasyPHP[0]
			If (FileExists($aEasyPHP[$i] & '\www')) Then
				$Liste[0] += 1     ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\www')     ;
			ElseIf (FileExists($aEasyPHP[$i] & '\eds-www')) Then
				$Liste[0] += 1         ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\eds-www')         ;
			ElseIf (FileExists($aEasyPHP[$i] & '\data\localweb')) Then
				$Liste[0] += 1             ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\data\localweb')
			ElseIf (FileExists($aEasyPHP[$i] & '\htdocs')) Then
				$Liste[0] += 1                 ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\htdocs')
			ElseIf (FileExists($aEasyPHP[$i] & '\xampp\htdocs')) Then
				$Liste[0] += 1                 ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\xampp\htdocs')
			EndIf
		Next
	EndIf

	Return $Liste
EndFunc   ;==>DossiersEasyPHPwww

;#########################################################################################

Func DossiersEasyPHPdata($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
	Local $aEasyPHP[1] = [0]
	Local $aTmpEasyPHP = _FileListToArrayRec(@HomeDrive, "EasyPHP*;wamp*;xampp*;apachefriends*", 30, 0, 2, $FullPath + 1)

	If IsArray($aTmpEasyPHP) Then
		$aEasyPHP[0] += $aTmpEasyPHP[0]
		_ArrayDelete($aTmpEasyPHP, 0)
		_ArrayAdd($aEasyPHP, $aTmpEasyPHP)
	EndIf

	Local $aTmpEasyPHP = _FileListToArray(@ProgramFilesDir, "EasyPHP*", 2, $FullPath)

	If IsArray($aTmpEasyPHP) Then
		$aEasyPHP[0] += $aTmpEasyPHP[0]
		_ArrayDelete($aTmpEasyPHP, 0)
		_ArrayAdd($aEasyPHP, $aTmpEasyPHP)
	EndIf

	Local $Liste[1] = [0], $data

	If IsArray($aEasyPHP) Then
		For $i = 1 To $aEasyPHP[0]
			$data = $aEasyPHP[$i] & '\mysql\data'  ;EasyPHP 1.x & 2.x & 3.x & 5.x & 6.x & 12.x
			If FileExists($data) Then
				$Liste[0] += 1 ;
				_ArrayAdd($Liste, $data) ;
			ElseIf FileExists($aEasyPHP[$i] & '\binaries\mysql\data') Then ;EasyPHP 13.x & 14.x
				$Liste[0] += 1 ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\binaries\mysql\data') ;
			ElseIf FileExists($aEasyPHP[$i] & '\eds-binaries\dbserver') Then  ;EasyPHP 15.x & 16.x & 17.x
				$data = _FindDataFldr($aEasyPHP[$i] & '\eds-binaries\dbserver')  ;EasyPHP 15.x & 16.x & 17.x
				If FileExists($data) Then
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $data) ;
				EndIf
			ElseIf (FileExists($aEasyPHP[$i] & '\bin\mysql')) Then ;Wamp
				$data = _FindDataFldr($aEasyPHP[$i] & '\bin\mysql')
				If FileExists($data) Then
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $data) ;
				EndIf
			ElseIf FileExists($aEasyPHP[$i] & '\xampp\mysql\data') Then ;EasyPHP 13.x & 14.x
				$Liste[0] += 1 ;
				_ArrayAdd($Liste, $aEasyPHP[$i] & '\xampp\mysql\data') ;
			EndIf
		Next
	EndIf
	Return $Liste
EndFunc   ;==>DossiersEasyPHPdata

;#########################################################################################

Func _FindDataFldr($PathEasy)
	Local $aSearch = _FileListToArrayRec($PathEasy, "data", 2, 1, 0, 2)
	If IsArray($aSearch) Then Return $aSearch[1]

	Return 0
EndFunc   ;==>_FindDataFldr

;#########################################################################################

Func _KillOtherScript()
	Local $list = ProcessList()
	For $i = 1 To $list[0][0]
		If $list[$i][0] = @ScriptName Then
			If $list[$i][1] <> @AutoItPID Then
				; Kill process
				$r = ProcessClose($list[$i][1])
			EndIf
		EndIf
	Next
EndFunc   ;==>_KillOtherScript

;#########################################################################################

Func _LockFolder($Dossier)
	If FileExists($Dossier) = 0 Then Return SetError(1, 0, -1)
	RunWait('"' & @ComSpec & '" /c cacls.exe "' & $Dossier & '" /E /P "' & @UserName & '":N', '', @SW_HIDE)
EndFunc   ;==>_LockFolder

;#########################################################################################

Func _UnlockFolder($Dossier)
	If FileExists($Dossier) = 0 Then Return SetError(1, 0, -1)
	RunWait('"' & @ComSpec & '" /c cacls.exe "' & $Dossier & '" /E /P "' & @UserName & '":F', '', @SW_HIDE)
EndFunc   ;==>_UnlockFolder

;#########################################################################################

Func _GetUserLocal()
	$GetTempDir = EnvGet("TEMP") ;This used to get to Local folders for XP and Vista/7
	$LongName = StringTrimRight($GetTempDir, 5)
	Local $UserLocal = FileGetLongName($LongName)
	$OS = @OSVersion
	If $OS = "WIN_XP" Then $UserLocal = FileGetLongName($LongName & "\Application Data")
	Return $UserLocal
EndFunc   ;==>_GetUserLocal

;#########################################################################################

Func _IsFileDiff($sFilePath_1, $sFilePath_2) ;return True if the 2 files are different
	Return Not (_MD5ForFile($sFilePath_1) == _MD5ForFile($sFilePath_2))
EndFunc   ;==>_IsFileDiff

;#########################################################################################

Func _FineSize($iTaille) ;reçoit une taille en Octet >> retourne la taille en "multiple" approprié Ko, Mo, Go...
	Local $aMultiples[9] = [" oct.", " Ko", " Mo", " Go", " To", " Po", " Eo", " Zo", " Yo"]  ;Kilo, Mega, Giga, Tera, Peta, Exa, Zeta, Yota
	Local $i = 0
	While ($iTaille >= 1024) And ($i < 8)
		$iTaille = Round($iTaille / 1024, 1)
		$i += 1
	WEnd

	Return $iTaille & $aMultiples[$i]
EndFunc   ;==>_FineSize

;#########################################################################################

; #FUNCTION# ;===============================================================================
;
; Name...........: _MD5ForFile
; Description ...: Calculates MD5 value for the specific file.
; Syntax.........: _MD5ForFile ($sFile)
; Parameters ....: $sFile - Full path to the file to process.
; Return values .: Success - Returns MD5 value in form of hex string
;                          - Sets @error to 0
;                  Failure - Returns empty string and sets @error:
;                  |1 - CreateFile function or call to it failed.
;                  |2 - CreateFileMapping function or call to it failed.
;                  |3 - MapViewOfFile function or call to it failed.
;                  |4 - MD5Init function or call to it failed.
;                  |5 - MD5Update function or call to it failed.
;                  |6 - MD5Final function or call to it failed.
; Author ........: trancexx
; Link ..........: https://www.autoitscript.com/forum/topic/95558-crc32-md4-md5-sha1-for-files/
;==========================================================================================
Func _MD5ForFile($sFile)

	Local $a_hCall = DllCall("kernel32.dll", "hwnd", "CreateFileW", _
			"wstr", $sFile, _
			"dword", 0x80000000, _ ; GENERIC_READ
			"dword", 3, _ ; FILE_SHARE_READ|FILE_SHARE_WRITE
			"ptr", 0, _
			"dword", 3, _ ; OPEN_EXISTING
			"dword", 0, _ ; SECURITY_ANONYMOUS
			"ptr", 0)

	If @error Or $a_hCall[0] = -1 Then
		Return SetError(1, 0, "")
	EndIf

	Local $hFile = $a_hCall[0]

	$a_hCall = DllCall("kernel32.dll", "ptr", "CreateFileMappingW", _
			"hwnd", $hFile, _
			"dword", 0, _ ; default security descriptor
			"dword", 2, _ ; PAGE_READONLY
			"dword", 0, _
			"dword", 0, _
			"ptr", 0)

	If @error Or Not $a_hCall[0] Then
		DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFile)
		Return SetError(2, 0, "")
	EndIf

	DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFile)

	Local $hFileMappingObject = $a_hCall[0]

	$a_hCall = DllCall("kernel32.dll", "ptr", "MapViewOfFile", _
			"hwnd", $hFileMappingObject, _
			"dword", 4, _ ; FILE_MAP_READ
			"dword", 0, _
			"dword", 0, _
			"dword", 0)

	If @error Or Not $a_hCall[0] Then
		DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFileMappingObject)
		Return SetError(3, 0, "")
	EndIf

	Local $pFile = $a_hCall[0]
	Local $iBufferSize = FileGetSize($sFile)

	Local $tMD5_CTX = DllStructCreate("dword i[2];" & _
			"dword buf[4];" & _
			"ubyte in[64];" & _
			"ubyte digest[16]")

	DllCall("advapi32.dll", "none", "MD5Init", "ptr", DllStructGetPtr($tMD5_CTX))

	If @error Then
		DllCall("kernel32.dll", "int", "UnmapViewOfFile", "ptr", $pFile)
		DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFileMappingObject)
		Return SetError(4, 0, "")
	EndIf

	DllCall("advapi32.dll", "none", "MD5Update", _
			"ptr", DllStructGetPtr($tMD5_CTX), _
			"ptr", $pFile, _
			"dword", $iBufferSize)

	If @error Then
		DllCall("kernel32.dll", "int", "UnmapViewOfFile", "ptr", $pFile)
		DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFileMappingObject)
		Return SetError(5, 0, "")
	EndIf

	DllCall("advapi32.dll", "none", "MD5Final", "ptr", DllStructGetPtr($tMD5_CTX))

	If @error Then
		DllCall("kernel32.dll", "int", "UnmapViewOfFile", "ptr", $pFile)
		DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFileMappingObject)
		Return SetError(6, 0, "")
	EndIf

	DllCall("kernel32.dll", "int", "UnmapViewOfFile", "ptr", $pFile)
	DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hFileMappingObject)

	Local $sMD5 = Hex(DllStructGetData($tMD5_CTX, "digest"))

	Return SetError(0, 0, $sMD5)

EndFunc   ;==>_MD5ForFile

;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

; MsgBox($MB_SYSTEMMODAL, 'dossier', $www, 360)
; _ArrayDisplay($Liste, 'BacBackup 1.0.0',"",32,Default ,"Liste de Dossiers/Fichiers Surveillés")

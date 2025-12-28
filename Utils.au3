#include-once
#include <Array.au3>
#include <File.au3>
#include <WinAPIFiles.au3>

Global $UserLocal = _GetUserLocal()
; Au moins 15 Go d'espace libre pour garantir que Windows peut fonctionner correctement
Global Const $MINIMUM_WINDOWS_FREE_SPACE = 15000 ; en MB
; 5 Go minimum requis pour un lecteur non-système
Global Const $FREE_SPACE_DRIVE_BACKUP = 5000 ; en MB
; Cache global pour les installations XAMPP-LITE/XAMPP/WAMP
Global $__g_aEasyPHPRootsCache = 0

; ============================================================================
Func DossiersBac($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
    Local $aResult = _FileListToArray( _
        StringLeft(@WindowsDir, 2), _
        "bac*2*", _
        $FLTAR_FOLDERS + $FLTAR_NOHIDDEN + $FLTAR_NOSYSTEM + $FLTAR_NOLINK, _
        $FullPath ? $FLTAR_FULLPATH : $FLTAR_RELPATH)

    If Not IsArray($aResult) Then Return _EmptyArray()
    Return $aResult
EndFunc
; ============================================================================
Func _DossiersTravailEleves($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
    Local $aResult = _FileListToArrayRec(StringLeft(@WindowsDir, 2), _
        "1*;2*;3*;4*;7*;8*;9*;bac*2*;dc*;ds*", _
        $FLTAR_FOLDERS + $FLTAR_NOHIDDEN + $FLTAR_NOSYSTEM + $FLTAR_NOLINK, _
        $FLTAR_NORECUR, $FLTAR_FASTSORT, $FullPath ? $FLTAR_FULLPATH : $FLTAR_RELPATH)

    If Not IsArray($aResult) Then Return _EmptyArray()
    Return $aResult
EndFunc

; ============================================================================
Func _DossiersSurBureau($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
    Local $aResult = _FileListToArrayRec(@DesktopDir, _
        "1*;2*;3*;4*;7*;8*;9*;bac*2*;dc*;ds*", _
        $FLTAR_FOLDERS + $FLTAR_NOHIDDEN + $FLTAR_NOSYSTEM + $FLTAR_NOLINK, _
        $FLTAR_NORECUR, $FLTAR_FASTSORT, $FullPath ? $FLTAR_FULLPATH : $FLTAR_RELPATH)

    If Not IsArray($aResult) Then Return _EmptyArray()
    Return $aResult
EndFunc

; ============================================================================
; Initialise le cache des installations WAMP/XAMPP
Func DossiersEasyPHPwww($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
    Local $aEasyPHP

    ; Récupère depuis le cache ou effectue le scan
    If IsArray($__g_aEasyPHPRootsCache) Then
        $aEasyPHP = $__g_aEasyPHPRootsCache
    Else
        $aEasyPHP = _FileListToArrayRec( _
            StringLeft(@WindowsDir, 2), _
            "wamp*;xampp*", _
            $FLTAR_FOLDERS + $FLTAR_NOHIDDEN + $FLTAR_NOSYSTEM + $FLTAR_NOLINK, _
            $FLTAR_NORECUR, _
            $FLTAR_FASTSORT, _
            $FullPath ? $FLTAR_FULLPATH : $FLTAR_RELPATH)

        ; Stocke dans le cache même si vide
        If Not IsArray($aEasyPHP) Then
            $__g_aEasyPHPRootsCache = _EmptyArray()
            Return _EmptyArray()
        EndIf
        $__g_aEasyPHPRootsCache = $aEasyPHP
    EndIf

    If $aEasyPHP[0] = 0 Then Return _EmptyArray()

    ; Construction du tableau résultat
    Local $aResult[$aEasyPHP[0] + 1]
    Local $iCount = 0

    For $i = 1 To $aEasyPHP[0]
        Local $sFolder = $aEasyPHP[$i]

        If FileExists($sFolder & '\www') Then
            $iCount += 1
            $aResult[$iCount] = $sFolder & '\www'
        ElseIf FileExists($sFolder & '\htdocs') Then
            $iCount += 1
            $aResult[$iCount] = $sFolder & '\htdocs'
        EndIf
    Next

    If $iCount = 0 Then Return _EmptyArray()

    ReDim $aResult[$iCount + 1]
    $aResult[0] = $iCount
    Return $aResult
EndFunc

; ============================================================================
; Utilise le cache et l'invalide après usage
Func DossiersEasyPHPdata($FullPath = 1) ; 1:Chemins complets, 0:Chemins relatifs
    Local $aEasyPHP

    ; Récupère le cache préparé par DossiersEasyPHPwww
    If IsArray($__g_aEasyPHPRootsCache) Then
        $aEasyPHP = $__g_aEasyPHPRootsCache
        $__g_aEasyPHPRootsCache = 0 ; Invalidation immédiate
    Else
        ; Fallback si appelé sans DossiersEasyPHPwww
        $aEasyPHP = _FileListToArrayRec( _
            StringLeft(@WindowsDir, 2), _
            "wamp*;xampp*", _
            $FLTAR_FOLDERS + $FLTAR_NOHIDDEN + $FLTAR_NOSYSTEM + $FLTAR_NOLINK, _
            $FLTAR_NORECUR, _
            $FLTAR_FASTSORT, _
            $FullPath ? $FLTAR_FULLPATH : $FLTAR_RELPATH)

        If Not IsArray($aEasyPHP) Then Return _EmptyArray()
    EndIf

    If $aEasyPHP[0] = 0 Then Return _EmptyArray()

    ; Pré-allocation pour MySQL + MariaDB par installation
    Local $aResult[$aEasyPHP[0] * 2 + 1]
    Local $iCount = 0

    For $i = 1 To $aEasyPHP[0]
        Local $sBase = $aEasyPHP[$i]
        Local $sDataPath

        ; XAMPP Lite
        $sDataPath = $sBase & '\apps\mysql\data'
        If FileExists($sDataPath) Then
            $iCount += 1
            $aResult[$iCount] = $sDataPath
            ContinueLoop
        EndIf

        ; EasyPHP/XAMPP standard
        $sDataPath = $sBase & '\mysql\data'
        If FileExists($sDataPath) Then
            $iCount += 1
            $aResult[$iCount] = $sDataPath
            ContinueLoop
        EndIf

        ; WampServer MySQL
        If FileExists($sBase & '\bin\mysql') Then
            $sDataPath = _FindDataFldr($sBase & '\bin\mysql')
            If $sDataPath <> "" Then
                $iCount += 1
                $aResult[$iCount] = $sDataPath
            EndIf
        EndIf

        ; WampServer MariaDB
        If FileExists($sBase & '\bin\mariadb') Then
            $sDataPath = _FindDataFldr($sBase & '\bin\mariadb')
            If $sDataPath <> "" Then
                $iCount += 1
                $aResult[$iCount] = $sDataPath
            EndIf
        EndIf
    Next

    If $iCount = 0 Then Return _EmptyArray()

    ReDim $aResult[$iCount + 1]
    $aResult[0] = $iCount
    Return $aResult
EndFunc

; ============================================================================
; Recherche le dossier data dans les installations WampServer versionnées
; Exemple: C:\wamp64\bin\mysql\mysql8.0.34\data
Func _FindDataFldr($PathEasy)
    Local $hSearch = FileFindFirstFile($PathEasy & "\*")
    If $hSearch = -1 Then Return ""

    Local $sEntry, $sCandidate
    While 1
        $sEntry = FileFindNextFile($hSearch)
        If @error Then ExitLoop

        ; Vérifie les dossiers versionnés (mysql*, mariadb*)
        If StringRegExp($sEntry, "(?i)^(mysql|mariadb)", 0) Then
            $sCandidate = $PathEasy & "\" & $sEntry & "\data"
            If FileExists($sCandidate) Then
                FileClose($hSearch)
                Return $sCandidate
            EndIf
        EndIf
    WEnd

    FileClose($hSearch)
    Return ""
EndFunc

; ============================================================================
Func _EmptyArray()
    Local $aEmpty[1] = [0]
    Return $aEmpty
EndFunc
;#########################################################################################

Func LecteurSauvegarde()
    Local $aDrives = DriveGetDrive('FIXED')
    Local $sHomeDrive = StringLeft(@WindowsDir, 2) ; dans certains cas @HomeDrive retourne une chaîne vide

    ; Si aucun lecteur fixe détecté, retourne le lecteur système
    If Not IsArray($aDrives) Then Return StringUpper($sHomeDrive) & "\"

    ; Vérifie d'abord si le lecteur système a assez d'espace
    If DriveSpaceFree($sHomeDrive & "\") > $MINIMUM_WINDOWS_FREE_SPACE Then
        Return StringUpper($sHomeDrive) & "\"
    EndIf

    ; Cherche un autre lecteur avec plus d'espace
    For $i = 1 To $aDrives[0]
        Local $sDrive = $aDrives[$i]

        ; Ignore le lecteur système (déjà testé)
        If $sDrive = $sHomeDrive Then ContinueLoop

        ; Vérifie les critères : non-USB, accessible en écriture, espace suffisant
        If DriveGetType($sDrive, $DT_BUSTYPE) <> "USB" _
            And _WinAPI_IsWritable($sDrive) _
            And DriveSpaceFree($sDrive & "\") > $FREE_SPACE_DRIVE_BACKUP Then
            Return StringUpper($sDrive) & "\"
        EndIf
    Next

    ; Aucun lecteur valide trouvé, retourne le lecteur système par défaut
    Return StringUpper($sHomeDrive) & "\"
EndFunc
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
    If Not FileExists($Dossier) Then Return SetError(1, 0, -1)

    Local $sCmd
    ; Utilise cacls.exe sous Windows 7, icacls.exe pour les versions ultérieures
    If @OSVersion = "WIN_7" Then
        $sCmd = 'cacls.exe "' & $Dossier & '" /E /P "' & @UserName & '":N > NUL 2>&1'
    Else
        $sCmd = 'icacls.exe "' & $Dossier & '" /deny "' & @UserName & '":(F) /c > NUL 2>&1'
    EndIf

    RunWait(@ComSpec & ' /c ' & $sCmd, "", @SW_HIDE)
EndFunc
;#########################################################################################

Func _UnlockFolder($Dossier)
    If Not FileExists($Dossier) Then Return SetError(1, 0, -1)

    Local $sCmd
    ; Utilise cacls.exe sous Windows 7, icacls.exe pour les versions ultérieures
    If @OSVersion = "WIN_7" Then
        $sCmd = 'cacls.exe "' & $Dossier & '" /E /P "' & @UserName & '":F > NUL 2>&1'
    Else
        ; Supprime toutes les permissions de l'utilisateur puis accorde un contrôle total
        $sCmd = 'icacls.exe "' & $Dossier & '" /remove "' & @UserName & '" > NUL 2>&1 & ' & _
                'icacls.exe "' & $Dossier & '" /grant "' & @UserName & '":F > NUL 2>&1'
    EndIf

    RunWait(@ComSpec & ' /c ' & $sCmd, "", @SW_HIDE)
EndFunc
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
; #FUNCTION# ====================================================================================================================
; Name ..........: _CRC32ForString
; Description ...: Calculates the CRC32 checksum for a string (CRC-32/ISO-HDLC).
; Syntax ........: _CRC32ForString($sString)
; Parameters ....: $sString - The string to process.
; Return values .: Success - Returns CRC32 value as an 8-character hex string.
;                  Failure - Returns an empty string and sets @error:
;                  |1 - Error during DLL call or memory structure creation.
; Author ........: romoez (GitHub: https://github.com/romoez/BacBackup)
; Modified from .: trancexx's _CRC32ForFile (https://www.autoitscript.com/forum/topic/95558-crc32-md4-md5-sha1-for-files/)
; ===============================================================================================================================
Func _CRC32ForString($sString)
    ; 1. Convert string to UTF-8 binary format
    Local $bBinary = StringToBinary($sString, 4) ; 4 = UTF-8 encoding

    ; 2. Get the actual size in bytes (BinaryLen) instead of character count (StringLen).
    ; This is crucial because in UTF-8, special characters (like accents or emojis)
    ; can use more than 1 byte, while StringLen would only count them as 1.
    Local $iByteLen = BinaryLen($bBinary)

    ; If the string is empty, return the CRC32 for an empty buffer
    If $iByteLen = 0 Then Return Hex(0, 8)

    ; 3. Create a memory structure to hold the bytes for the DLL call
    Local $tData = DllStructCreate("byte[" & $iByteLen & "]")
    If @error Then Return SetError(1, 0, "") ; Memory allocation failed

    DllStructSetData($tData, 1, $bBinary)

    ; 4. Call RtlComputeCrc32 from ntdll.dll (native Windows function)
    ; This is significantly faster than an AutoIt loop for CRC calculation.
    Local $a_iCall = DllCall("ntdll.dll", "dword", "RtlComputeCrc32", _
            "dword", 0, _ ; Initial CRC value
            "ptr", DllStructGetPtr($tData), _ ; Pointer to data
            "int", $iByteLen) ; Length in bytes

    ; Check for DllCall errors
    If @error Or Not IsArray($a_iCall) Then
        Return SetError(1, 0, "")
    EndIf

    ; 5. Return the result as a formatted 8-character hexadecimal string
    Local $iCRC32 = $a_iCall[0]
    Return SetError(0, 0, Hex($iCRC32, 8))
EndFunc   ;==>_CRC32ForString
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
; #FUNCTION# ====================================================================================================================
; Name ..........: _MD5ForString
; Description ...: Calculates the MD5 hash for a string.
; Syntax ........: _MD5ForString($sString)
; Parameters ....: $sString - The string to process.
; Return values .: Success - Returns MD5 value as a 32-character hex string.
;                  Failure - Returns an empty string and sets @error:
;                  |1 - Error during memory structure creation.
;                  |2 - MD5Init function call failed.
;                  |3 - MD5Update function call failed.
;                  |4 - MD5Final function call failed.
; Author ........: romoez (GitHub: https://github.com/romoez/BacBackup)
; Modified from .: trancexx's _MD5ForFile (https://www.autoitscript.com/forum/topic/95558-crc32-md4-md5-sha1-for-files/)
; ===============================================================================================================================
Func _MD5ForString($sString)
    ; 1. Convert string to UTF-8 binary format
    Local $bBinary = StringToBinary($sString, 4) ; 4 = UTF-8 encoding

    ; 2. Get the actual size in bytes (BinaryLen) instead of character count (StringLen).
    ; This is crucial because in UTF-8, special characters (like accents or emojis)
    ; can use more than 1 byte, while StringLen would only count them as 1.
    Local $iByteLen = BinaryLen($bBinary)

    ; If the string is empty, calculate MD5 for an empty buffer
    If $iByteLen = 0 Then
        $bBinary = Binary("") ; Empty binary
        $iByteLen = 0
    EndIf

    ; 3. Create a memory structure to hold the bytes
    Local $tData = DllStructCreate("byte[" & ($iByteLen > 0 ? $iByteLen : 1) & "]")
    If @error Then Return SetError(1, 0, "") ; Memory allocation failed

    If $iByteLen > 0 Then
        DllStructSetData($tData, 1, $bBinary)
    EndIf

    ; 4. Create MD5 context structure (required by advapi32.dll MD5 functions)
    Local $tMD5_CTX = DllStructCreate("dword i[2];" & _
            "dword buf[4];" & _
            "ubyte in[64];" & _
            "ubyte digest[16]")

    If @error Then Return SetError(1, 0, "") ; Memory allocation failed

    ; 5. Initialize MD5 context
    DllCall("advapi32.dll", "none", "MD5Init", "ptr", DllStructGetPtr($tMD5_CTX))

    If @error Then
        Return SetError(2, 0, "")
    EndIf

    ; 6. Update MD5 context with data
    DllCall("advapi32.dll", "none", "MD5Update", _
            "ptr", DllStructGetPtr($tMD5_CTX), _
            "ptr", DllStructGetPtr($tData), _
            "dword", $iByteLen)

    If @error Then
        Return SetError(3, 0, "")
    EndIf

    ; 7. Finalize MD5 calculation
    DllCall("advapi32.dll", "none", "MD5Final", "ptr", DllStructGetPtr($tMD5_CTX))

    If @error Then
        Return SetError(4, 0, "")
    EndIf

    ; 8. Extract and format the MD5 digest as a 32-character hexadecimal string
    Local $sMD5 = Hex(DllStructGetData($tMD5_CTX, "digest"))

    Return SetError(0, 0, $sMD5)

EndFunc   ;==>_MD5ForString

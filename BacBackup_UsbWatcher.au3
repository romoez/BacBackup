#NoTrayIcon
#Region ;**** Directives AutoIt3Wrapper ****
#AutoIt3Wrapper_Run_Au3Stripper=y
;~ #Au3Stripper_Parameters=/rm /mo /sf /sv
#Au3Stripper_Parameters=/rm /sf /sv
#AutoIt3Wrapper_UseUpx=n
#EndRegion

#Region ;**** Métadonnées de l'application ****
#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup - USB Watcher)
#pragma compile(FileVersion, 2.5.26.218)
#pragma compile(ProductVersion, 2.5.26.218)
#pragma compile(ProductName, BacBackup)
#pragma compile(InternalName, BacBackup_UsbWatcher)
#pragma compile(OriginalFilename, BacBackup_UsbWatcher.exe)
#pragma compile(AutoItExecuteAllowed, false)
#pragma compile(InputBoxRes, true)
#pragma compile(Compatibility, vista, win7, win8, win10, win11)
#pragma compile(Console, false)
#EndRegion

#Region ;**** Informations légales ****
#pragma compile(LegalCopyright, © 2016-2026 Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments, Module de sauvegarde automatique - Exécuté par le service principal BacBackup)
#pragma compile(CompanyName, CTEI - Communauté Tunisienne des Enseignants d'Informatique)
#EndRegion

#Region ;**** Configuration de sortie ****
#pragma compile(Out, Installer\Files\BacBackup_UsbWatcher.exe)
#EndRegion


;~ #include <FileConstants.au3>
#include <String.au3>
#include <WinAPIFiles.au3>
#include <Array.au3>
#include <File.au3>
#include <ScreenCapture.au3>
#include <Utils.au3>


If $CMDLINE[0] < 2 Then
	Exit
EndIf

;~ Forcer le mode "DPI Aware" pour capturer la totalité de l'écran
DllCall("user32.dll", "bool", "SetProcessDPIAware")

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@         initialisation           @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Global $FullPathDossierSession = $CMDLINE[2] & "\_UsbWatcher"

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Début Programme Principal    @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

_KillOtherScript()
Init()

Func Init()
	; Vérification des paramètres de ligne de commande
	If Not ($CMDLINE[0] > 0 And FileExists($CMDLINE[1])) Then Return

	; Normaliser la lettre de lecteur (ex: "E:" ou "E" -> "E:")
	Local $sDriveLetter = StringUpper(StringLeft($CMDLINE[1], 1)) & ":"

	; Vérifier si BacCollector existe dans les sous-dossiers
	If CheckBacCollectorInFirstLevelFolders($sDriveLetter) Then Return

	; Créer le dossier de session principal si nécessaire
	If Not FileExists($FullPathDossierSession) Then
		If Not DirCreate($FullPathDossierSession) Then Return
	EndIf

	; ═══════════════════════════════════════════════════════════════
	; RÉCUPÉRATION DES INFORMATIONS USB
	; ═══════════════════════════════════════════════════════════════
	Local $aUsbInfo = _GetUsbDriveInfo($sDriveLetter)
	Local $sSerialNumber = ""
	Local $sInfoUSB = ""

	If @error = 0 And IsArray($aUsbInfo) And UBound($aUsbInfo) = 6 Then
		; Valider le numéro de série (caractères alphanumériques + - _ . espace)
		If StringRegExp($aUsbInfo[1], "^[A-Za-z0-9_ \-\.]+$") Then
			$sSerialNumber = $aUsbInfo[1]
		EndIf

		; Formater les informations USB
		$sInfoUSB = "Marque/Modèle    : " & $aUsbInfo[0] & @CRLF & _
		            "Série Matériel   : " & $aUsbInfo[1] & @CRLF & _
		            "Série Volume     : " & $aUsbInfo[2] & @CRLF & _
		            "Capacité         : " & _OctetsVersGo($aUsbInfo[3]) & " Go" & @CRLF & _
		            "Étiquette        : " & ($aUsbInfo[4] <> "" ? $aUsbInfo[4] : "(Aucune)") & @CRLF & _
		            "Système Fichiers : " & $aUsbInfo[5]
	EndIf

	; ═══════════════════════════════════════════════════════════════
	; CRÉATION DU NOM DE DOSSIER UNIQUE
	; ═══════════════════════════════════════════════════════════════
	Local $sTimestamp = StringFormat("%02d", @HOUR) & "_" & _
	                    StringFormat("%02d", @MIN) & "_" & _
	                    StringFormat("%02d", @SEC)

	; Ajouter le S/N si valide
	Local $sNomDossier = ($sSerialNumber <> "") ? $sTimestamp & "___SN__" & $sSerialNumber : $sTimestamp

	$FullPathDossierSession &= "\" & $sNomDossier

	; Gérer les doublons (suffixe _0, _1, _2...)
	If FileExists($FullPathDossierSession) Then
		Local $iSuffix = 0
		While FileExists($FullPathDossierSession & "_" & $iSuffix)
			$iSuffix += 1
		WEnd
		$FullPathDossierSession &= "_" & $iSuffix
	EndIf

	; Créer le dossier final
	If Not DirCreate($FullPathDossierSession) Then Return

	; ═══════════════════════════════════════════════════════════════
	; ÉCRITURE DU FICHIER DE LOG
	; ═══════════════════════════════════════════════════════════════
	Local $sLogFile = $FullPathDossierSession & "\_ContenuCléUSB.txt"
	Local $hInfoFile = FileOpen($sLogFile, $FO_OVERWRITE + $FO_UTF8_NOBOM)

	If $hInfoFile <> -1 Then
		; Horodatage complet (ISO 8601)
		Local $sDateHeure = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
		                    " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)

		; En-tête
		FileWriteLine($hInfoFile, _StringRepeat("═", 58))
		FileWriteLine($hInfoFile, "  ANALYSE CLÉ USB - BacBackup_UsbWatcher")
		FileWriteLine($hInfoFile, _StringRepeat("═", 58))
		FileWriteLine($hInfoFile, "")
		FileWriteLine($hInfoFile, "Date/Heure       : " & $sDateHeure)
		FileWriteLine($hInfoFile, "Lecteur          : " & $sDriveLetter)

		If $sInfoUSB <> "" Then
			FileWriteLine($hInfoFile, "")
			FileWriteLine($hInfoFile, $sInfoUSB)
		EndIf

		; Contenu de la clé
		FileWriteLine($hInfoFile, "")
		FileWriteLine($hInfoFile, _StringRepeat("─", 58))
		FileWriteLine($hInfoFile, "CONTENU DE LA CLÉ USB")
		FileWriteLine($hInfoFile, _StringRepeat("─", 58))
		FileWriteLine($hInfoFile, "")
		FileWriteLine($hInfoFile, $sDriveLetter & "\")

		Local $sArborescence = _DirTreeToString($sDriveLetter, 100)
		If $sArborescence <> "" Then
			FileWriteLine($hInfoFile, $sArborescence)
		Else
			FileWriteLine($hInfoFile, "(Clé vide ou inaccessible)")
		EndIf

		FileWriteLine($hInfoFile, "")
		FileWriteLine($hInfoFile, _StringRepeat("═", 58))

		FileClose($hInfoFile)
	EndIf

	; ═══════════════════════════════════════════════════════════════
	; CAPTURES D'ÉCRAN
	; ═══════════════════════════════════════════════════════════════
	_Capturer($FullPathDossierSession, 100)
EndFunc   ;==>Init

;#########################################################################################
Func _Capturer($FullPathDossierSession, $iNb)
	Local $sNomFichier
	For $i = 1 To $iNb
		; Numérotation sur 3 chiffres (001 à 100) + horodatage
		$sNomFichier = StringFormat("%03d", $i) & "_" & _
		               StringFormat("%02d", @HOUR) & "h" & _
		               StringFormat("%02d", @MIN) & "_" & _
		               StringFormat("%02d", @SEC) & ".png"

		_ScreenCapture_Capture($FullPathDossierSession & "\" & $sNomFichier)
;~ 		If @error Or Not FileExists($sDriveLetter) Then
		If @error Then
			Return
		EndIf

		Sleep(1500)
	Next
EndFunc   ;==>_Capturer


; #FUNCTION# ====================================================================================================================
; Name...........: _GetUsbDriveInfo
; Description ...: Récupère rapidement les informations d'une clé USB via WMI
; Syntax.........: _GetUsbDriveInfo($sDrive)
; Parameters ....: $sDrive - Lettre du lecteur (format: "E:")
; Return values .: Success - Tableau avec les informations:
;                  [0] = Modèle
;                  [1] = Série Matériel
;                  [2] = Série Volume
;                  [3] = Capacité en octets
;                  [4] = Étiquette
;                  [5] = Système de fichiers
;                  Failure - @error = 1 et tableau vide
; Author ........: Optimisé pour la performance
; Remarks .......: Le lecteur doit être amovible (vérifié avant l'appel)
; ===============================================================================================================================
Func _GetUsbDriveInfo($sDrive)
    Local $aInfo[6] = ["Inconnu", "Inconnu", "00000000", 0, "", "Inconnu"]
    Local $oWMI = Null, $oLogicalDisks = Null, $oPartitions = Null, $oDiskDrives = Null
    Local $oLogicalDisk = Null, $oPartition = Null, $oDiskDrive = Null

    ; Connexion WMI optimisée
    $oWMI = ObjGet("winmgmts:{impersonationLevel=impersonate}!\\" & @ComputerName & "\root\cimv2")
    If @error Or Not IsObj($oWMI) Then
        ; Tentative alternative
        $oWMI = ObjGet("winmgmts:\\.\root\cimv2")
        If @error Or Not IsObj($oWMI) Then
            Return SetError(1, 0, $aInfo)
        EndIf
    EndIf

    ; 1. Récupération du volume logique - requête directe optimisée
    $oLogicalDisks = $oWMI.ExecQuery('SELECT VolumeName, FileSystem, Size, FreeSpace, VolumeSerialNumber ' & _
                                     'FROM Win32_LogicalDisk WHERE DeviceID="' & $sDrive & '"')

    If Not IsObj($oLogicalDisks) Or $oLogicalDisks.Count = 0 Then
        Return SetError(1, 0, $aInfo)
    EndIf

    ; Parcours unique optimisé
    For $oLogicalDisk In $oLogicalDisks
        ; Remplir les informations du volume
        $aInfo[4] = $oLogicalDisk.VolumeName  ; Étiquette
        $aInfo[5] = $oLogicalDisk.FileSystem  ; Système de fichiers
        $aInfo[3] = $oLogicalDisk.Size        ; Capacité
        $aInfo[2] = $oLogicalDisk.VolumeSerialNumber  ; Série Volume

        ; 2. Recherche de la partition associée - requête optimisée
        $oPartitions = $oWMI.ExecQuery("ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='" & $sDrive & "'} " & _
                                       "WHERE AssocClass=Win32_LogicalDiskToPartition")

        If Not IsObj($oPartitions) Or $oPartitions.Count = 0 Then
            Return $aInfo  ; Retourner au moins les infos du volume
        EndIf

        For $oPartition In $oPartitions
            ; 3. Recherche du disque physique - requête optimisée
            $oDiskDrives = $oWMI.ExecQuery("ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" & $oPartition.DeviceID & "'} " & _
                                           "WHERE AssocClass=Win32_DiskDriveToDiskPartition")

            If Not IsObj($oDiskDrives) Or $oDiskDrives.Count = 0 Then
                Return $aInfo  ; Retourner au moins les infos du volume
            EndIf

            For $oDiskDrive In $oDiskDrives
                ; Récupération des infos matérielles
                $aInfo[0] = StringStripWS($oDiskDrive.Model, $STR_STRIPTRAILING + $STR_STRIPLEADING)  ; Modèle
                $aInfo[1] = StringStripWS($oDiskDrive.SerialNumber, $STR_STRIPTRAILING + $STR_STRIPLEADING)  ; Série Matériel

                ; Si série matériel vide, utiliser celle du volume
                If $aInfo[1] = "" Then
                    $aInfo[1] = $aInfo[2]
                EndIf

                ExitLoop 3  ; Sortir des trois boucles
            Next
        Next
        ExitLoop
    Next

    ; Libération explicite des objets COM (bonne pratique)
    $oDiskDrive = Null
    $oPartition = Null
    $oLogicalDisk = Null
    $oDiskDrives = Null
    $oPartitions = Null
    $oLogicalDisks = Null
    $oWMI = Null

    Return $aInfo
EndFunc

Func _OctetsVersGo($octets)
    ; Calculer la taille en Go
    Local $go = $octets / 1073741824 ; 1 Go = 1024 * 1024 * 1024 octets

    ; Trouver la puissance de 2 la plus proche
    Local $puissance = 0
    While (2 ^ $puissance < $go)
        $puissance += 1
    WEnd

    ; Retourner la valeur arrondie
    Return 2 ^ $puissance
EndFunc


Func CheckBacCollectorInFirstLevelFolders($sDrive)
    ; S'assurer que le lecteur se termine par un backslash
    If StringRight($sDrive, 1) <> "\" Then $sDrive &= "\"

    ; Vérifier que le lecteur existe et n'est pas un lecteur réseau
    If DriveStatus($sDrive) <> "READY" Then Return False

    ; Rechercher les dossiers de premier niveau uniquement
    Local $hSearch = FileFindFirstFile($sDrive & "*")
    If $hSearch = -1 Then Return False

    Local $bFound = False

    While True
        Local $sFolder = FileFindNextFile($hSearch)
        If @error Then ExitLoop

        ; Construire le chemin complet
        Local $sFullPath = $sDrive & $sFolder

        ; Vérifier si c'est un dossier (ignorer "." et "..")
        Local $sAttrib = FileGetAttrib($sFullPath)
        If @error Then ContinueLoop ; Fichier inaccessible

        If StringInStr($sAttrib, "D") And $sFolder <> "." And $sFolder <> ".." Then
            ; Rechercher BacCollector*.* dans ce dossier uniquement
            Local $hFileSearch = FileFindFirstFile($sFullPath & "\BacCollector*.*")

            If $hFileSearch <> -1 Then
                FileClose($hFileSearch)
                $bFound = True
                ExitLoop
            EndIf
        EndIf
    WEnd

    FileClose($hSearch)
    Return $bFound
EndFunc   ;==>CheckBacCollectorInFirstLevelFolders

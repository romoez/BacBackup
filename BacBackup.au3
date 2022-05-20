#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_Compression=4
;~ #AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup Auto-Sauvegarde)
#pragma compile(FileVersion, 2.2.5.520, 2.2.5.520) ; Le dernier paramètre est optionnel
#pragma compile(ProductName, BacBackup)
#pragma compile(ProductVersion, 2.2.5.520)

#pragma compile(LegalCopyright, © La Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments,'BacBackup - Module de Surveillance')
#pragma compile(Out, Installer\Files\BacBackup.exe)
#pragma compile(CompanyName, La Communauté Tunisienne des Enseignants d'Informatique)

#include <ScreenCapture.au3>
#include <WinAPIFiles.au3>
#include <Utils.au3>

;---------------------------------------------------Variables Globales-Début
Global $scrnsave ;Définie dans la Func Initialisation()
Global $IntervalleInterSauvegardes ;Définie dans la Func Initialisation()
Global $IntervalleInterCaptures ; = 5 ; Secondes
Global $TaillMaxDossierSessionEnGO = 5 ; GigaOctets
Global $DossierSession
;---------------------------------------------------Variables Globales-Fin

;---------------------------------------------------Hotkeys-Début
;^ --> CTRL
;! --> ALT
;+ --> SHIFT
;^! --> CTRL+ALT==ALTGr (Dans certains Cas)
;# --> Win
HotKeySet("^#+{F6}", "AfficherInterface") ; CTRL+SHIFT+WIN+F6
HotKeySet("^#+{F5}", "LancerSauvegardeForcee") ; CTRL+SHIFT+WIN+F5
;---------------------------------------------------Hotkeys-Fin


;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Début Programme Principal    @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

_KillOtherScript()
Initialisation()
CleanUp()
main()

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Fin Programme Principal    @@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Func main()
	Local $NbCaptures
	Local $NombreTotalOperations = 0
	While 1
		$NbCaptures = 0
		While $NbCaptures * $IntervalleInterCaptures < $IntervalleInterSauvegardes
			$NbCaptures += 1
			Sleep($IntervalleInterCaptures)
			Capturer()
			$NombreTotalOperations += 1
		WEnd
		If $NombreTotalOperations >= 5000 Then
			If DirGetSize($DossierSession) / 1024 / 1024 / 1024 > $TaillMaxDossierSessionEnGO Then ;If Taille $DossierSession > 1 Go Then...
				CleanUp()
				Initialisation()
				$NombreTotalOperations = 0
			EndIf
		EndIf
		LancerSauvegardeNormale()
	WEnd
EndFunc   ;==>main

;#########################################################################################

Func Initialisation()
;~ -------------------------------------------------ScreenSaver Var:Utilisé pour déterminer le "Idle Time"-Début
	$scrnsave = RegRead("HKEY_CURRENT_USER\Control Panel\Desktop", "SCRNSAVE.EXE")
	$scrnsave = StringRight($scrnsave, StringLen($scrnsave) - StringInStr($scrnsave, "\", 0, -1))
;~ -------------------------------------------------ScreenSaver Var:Utilisé pour déterminer le "Idle Time"-Fin
	$Lecteur = LecteurSauvegarde()
	$DossierSauvegardes = "Sauvegardes"
	If Not FileExists($Lecteur & $DossierSauvegardes) Then
		DirCreate($Lecteur & $DossierSauvegardes)
	EndIf
	FileSetAttrib($Lecteur & $DossierSauvegardes, "+SH")

;~ Dossier Captures d'écran
	If Not FileExists($Lecteur & $DossierSauvegardes & "\BacBackup") Then
		_UnLockFolder($Lecteur & $DossierSauvegardes)
		DirCreate($Lecteur & $DossierSauvegardes & "\BacBackup")
	EndIf

	IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "DossierSauvegardes", $DossierSauvegardes)
	IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "Lecteur", StringUpper($Lecteur))
	_LockFolder($Lecteur & $DossierSauvegardes)

;~ Sous Dossier Captures d'écran
	Global $DossierSession = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "DossierSession", "")
	$Tmp = StringLeft($DossierSession, 3)
	If StringRegExp($Tmp, "([0-9]{3})", 0) = 0 Then
		$Tmp = "001"
	Else
		$Tmp = $Tmp + 1
		If $Tmp > 999 Then
			$Tmp = "001"
		EndIf
	EndIf
	$Tmp = "00" & $Tmp
	$Tmp = StringRight($Tmp, 3)

	$DossierSession = $Tmp & '___' & @MDAY & "_" & @MON & "_" & @YEAR & "___" & @HOUR & "h" & @MIN
	IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "DossierSession", $DossierSession)

	$DossierSession = StringUpper($Lecteur) & $DossierSauvegardes & "\BacBackup\" & $DossierSession
	If Not FileExists($DossierSession) Then
		DirCreate($DossierSession)
	EndIf
	If Not FileExists($DossierSession & "\0-CapturesÉcran") Then
		DirCreate($DossierSession & "\0-CapturesÉcran")
	EndIf

	$IntervalleInterSauvegardes = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "IntervalleInterSauvegardesEnMinutes", "")
	If StringIsInt($IntervalleInterSauvegardes) = 0 Or $IntervalleInterSauvegardes < 1 Or $IntervalleInterSauvegardes > 15 Then
		$IntervalleInterSauvegardes = 2 ;2 Minutes
		IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "IntervalleInterSauvegardesEnMinutes", $IntervalleInterSauvegardes)
	EndIf
	$IntervalleInterSauvegardes = $IntervalleInterSauvegardes * 60000 ; (1 minute= 60000 millisecondes)

	$IntervalleInterCaptures = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "IntervalleInterCapturesEnSecondes", "")
	If StringIsInt($IntervalleInterCaptures) = 0 Or $IntervalleInterCaptures < 2 Or $IntervalleInterCaptures > 20 Then
		$IntervalleInterCaptures = 5 ;5 Secondes
		IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "IntervalleInterCapturesEnSecondes", $IntervalleInterCaptures)
	EndIf
	$IntervalleInterCaptures *= 1000
EndFunc   ;==>Initialisation

;#########################################################################################

Func Capturer($NbAppelRecursif = 0)
	Local $iIdleTime = _Timer_GetIdleTime()
	If $iIdleTime <= $IntervalleInterCaptures And Not ProcessExists($scrnsave) And WinGetTitle("") <> "" Then
		Local $NomImage = @HOUR & "h_" & @MIN & "_" & @SEC & ".png"
		_ScreenCapture_Capture($DossierSession & "\0-CapturesÉcran\" & $NomImage)
		;Si une erreur est produite (Formatage de D:\, Suppression  du dossier de Sauvegarde...) On appelle la Func Initialisation()

		If @error <> 0 Then
			If $NbAppelRecursif > 2 Then
				$IntervalleInterCaptures += $IntervalleInterCaptures ;après 3 appels récursifs, on double l'$IntervalleInterCaptures
				Return ; et on quitte la Func
			EndIf
			Initialisation()
			$NbAppelRecursif += 1 ;
			Capturer($NbAppelRecursif)
		EndIf
	EndIf
EndFunc   ;==>Capturer

;#########################################################################################

Func LancerSauvegardeForcee()
	Capturer()
	ShellExecute(@ScriptDir & "\BacBackup_Sauvegarder.exe", 'forcee')
EndFunc   ;==>LancerSauvegardeForcee

;#########################################################################################

Func LancerSauvegardeNormale()
	Capturer()
	Local $iIdleTime = _Timer_GetIdleTime()
	If $iIdleTime <= $IntervalleInterSauvegardes And Not ProcessExists($scrnsave) And WinGetTitle("") <> "" Then
		ShellExecute(@ScriptDir & "\BacBackup_Sauvegarder.exe", 'normale')
	EndIf
EndFunc   ;==>LancerSauvegardeNormale

;#########################################################################################

Func AfficherInterface()
	LancerSauvegardeNormale()
	ShellExecute(@ScriptDir & "\BacBackup_Interface.exe", StringRegExpReplace($DossierSession, "(\\\w*)$", ""))
EndFunc   ;==>AfficherInterface

;#########################################################################################

Func OuvrirDossierDeSauvegarde()
	;--------------------------
	$CheminSauve = IniRead(StringRegExpReplace($DossierSession, "(\\\w*)$", "") & "\BacBackup.ini", "Params", "DossierSauvegardes", "")
	Run("explorer.exe /e, " & '"' & $CheminSauve & '"')
EndFunc   ;==>OuvrirDossierDeSauvegarde

;#########################################################################################

Func CleanUp()
	Local Const $NombreMaxDeDossiersDeSauve_Seuil_Minimum = 50
	Local Const $NombreMaxDeDossiersDeSauve_Default_Value = 750
	Local Const $NombreMaxDeDossiersDeSauve_Seuil_Maximum = 1000

	Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Minimum = 25 ;Go
	Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Default_Value = 200 ;Go
	Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Maximum = 500 ;Go

	Local $TailleMaxDuDossierBacBackupEnGigaoctet = IniRead(StringRegExpReplace($DossierSession, "(\\\w*)$", "") & "\BacBackup.ini", "Params", "TailleMaxDuDossierBacBackupEnGigaoctet", "0")
;~ 	MsgBox ( 0, "", $TailleMaxDuDossierBacBackupEnGigaoctet  )
	If StringIsInt($TailleMaxDuDossierBacBackupEnGigaoctet) = 0 Or $TailleMaxDuDossierBacBackupEnGigaoctet < $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Minimum Or $TailleMaxDuDossierBacBackupEnGigaoctet > $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Maximum Then
		$TailleMaxDuDossierBacBackupEnGigaoctet = $TailleMaxDuDossierBacBackupEnGigaoctet_Default_Value
		IniWrite(StringRegExpReplace($DossierSession, "(\\\w*)$", "") & "\BacBackup.ini", "Params", "TailleMaxDuDossierBacBackupEnGigaoctet", $TailleMaxDuDossierBacBackupEnGigaoctet)
	EndIf

	$NombreMaxDeDossiersDeSauve = IniRead(StringRegExpReplace($DossierSession, "(\\\w*)$", "") & "\BacBackup.ini", "Params", "NombreMaxDeDossiersDeSauve", "0")
	If StringIsInt($NombreMaxDeDossiersDeSauve) = 0 Or $NombreMaxDeDossiersDeSauve < $NombreMaxDeDossiersDeSauve_Seuil_Minimum Or $NombreMaxDeDossiersDeSauve > $NombreMaxDeDossiersDeSauve_Seuil_Maximum Then
		$NombreMaxDeDossiersDeSauve = $NombreMaxDeDossiersDeSauve_Default_Value
		IniWrite(StringRegExpReplace($DossierSession, "(\\\w*)$", "") & "\BacBackup.ini", "Params", "NombreMaxDeDossiersDeSauve", $NombreMaxDeDossiersDeSauve)

	EndIf
	Local $aDrive = DriveGetDrive('FIXED')
	For $i = 1 To $aDrive[0]
		If (DriveGetType($aDrive[$i], $DT_BUSTYPE) <> "USB") _ ; pour Exclure les hdd externes
				And _WinAPI_IsWritable($aDrive[$i]) _
				Then
			$Lecteur = $aDrive[$i]
			$Chemin = $Lecteur & "\Sauvegardes"
			If Not FileExists($Chemin & "\BacBackup") Then ContinueLoop
			;======== Début Réinitialisation des Numéro Dossiers sSauve à 0
			If FileExists($Chemin & "\BacBackup\BacBackup.ini") Then
				$aDossiersEtNumeros = IniReadSection($Chemin & "\BacBackup\BacBackup.ini", "DerniersDossiers")
				If Not @error And IsArray($aDossiersEtNumeros) Then
					$k = 1
					While $k <= $aDossiersEtNumeros[0][0]

						$KesDossier = $aDossiersEtNumeros[$k][0]
						;== Le Dossier BK n'existe pas
						If Not FileExists($Chemin & "\Tmp\" & $KesDossier) Then
							_ArrayDelete($aDossiersEtNumeros, $k)
							$aDossiersEtNumeros[0][0] -= 1
							ContinueLoop
						EndIf
						;== Le lien n'existe pas
						If Not FileExists($Chemin & "\Tmp\" & $KesDossier & "\dossier d'origine.lnk") Then
							DirRemove($Chemin & "\Tmp\" & $KesDossier, 1)
							_ArrayDelete($aDossiersEtNumeros, $k)
							$aDossiersEtNumeros[0][0] -= 1
							ContinueLoop
						EndIf
						;== Le dossier d'origine n'existe pas ou raccourcis corrompu
						$aDetails = FileGetShortcut($Chemin & "\Tmp\" & $KesDossier & "\dossier d'origine.lnk")
						If @error Or Not FileExists($aDetails[0]) Then
							DirRemove($Chemin & "\Tmp\" & $KesDossier, 1)
							_ArrayDelete($aDossiersEtNumeros, $k)
							$aDossiersEtNumeros[0][0] -= 1
							ContinueLoop
						EndIf

						$aDossiersEtNumeros[$k][1] = "000"
						$k = $k + 1
					WEnd
					_ArraySort($aDossiersEtNumeros, 0, 1)
					IniWriteSection($Chemin & "\BacBackup\BacBackup.ini", "DerniersDossiers", $aDossiersEtNumeros)

				EndIf

			EndIf
			;======== Fin   Réinitialisation des Numéro Dossiers sSauve à 0

			$DossiersSessions = _FileListToArrayRec($Chemin & "\BacBackup", "*", 2, 0, 2, 2)

			If IsArray($DossiersSessions) And ($DossiersSessions[0] > $NombreMaxDeDossiersDeSauve / 10 _
					Or Round(DirGetSize($Chemin & "\BacBackup\") / 1024 / 1024 / 1024) > $TailleMaxDuDossierBacBackupEnGigaoctet) Then
				;*****************************************************
				For $j = Round($DossiersSessions[0] / 2) To 1 Step -1
					DirRemove($DossiersSessions[$j], 1)
				Next
			EndIf
			_LockFolder($Chemin)

		EndIf
	Next

	Return
EndFunc   ;==>CleanUp

;#########################################################################################

Func _Timer_GetIdleTime()
	Local $tStruct = DllStructCreate("uint;dword") ;
	DllStructSetData($tStruct, 1, DllStructGetSize($tStruct)) ;
	DllCall("user32.dll", "int", "GetLastInputInfo", "ptr", DllStructGetPtr($tStruct))

	Local $avTicks = DllCall("Kernel32.dll", "int", "GetTickCount")

	Local $iDiff = $avTicks[0] - DllStructGetData($tStruct, 2)
	If $iDiff >= 0 Then
		Return $iDiff
	Else
		Return SetError(0, 1, $avTicks[0])
	EndIf
EndFunc   ;==>_Timer_GetIdleTime


;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;■■■
;~ _ArrayDisplay($TmpList, $PROG_TITLE ,"",32,Default ,"Liste de Dossiers/Fichiers Surveillés")
;■■■
;~ MsgBox ( 0, "", $sDir  )
;■■■
;~ StringRegExpReplace($Path, "^.*\\", "") ;"C:\Program Files (x86)\EasyPHP-12.1\www\bd2013-14h" >>> "bd2013-14h"
;~ StringRegExpReplace($Path, "(\\\w*)$", "") ;"D:\Sauvegardes\BacBackup\031___09_02_2019___08h59" >>> "D:\Sauvegardes\BacBackup"

;■■■
;~ $sExtract = StringRegExpReplace($aFile_2[$i], "(?i)(?U).*\x20(.*)\x20country.*\z", "$1")
;~ 	(?i)             - case insensitive
;~ 	(?U)             - inverse greediness so we look for the smallest matches
;~ 	.*\x20           - any number of chars followed by a space (this reads the "<z:row " part before the bit we want)
;~ 	(.*)             - capture the characters (the bit we want) up to...
;~ 	\x20country.*\z  - a space followed by "country" and any other characters to the end of the line (this reads everything after the bit we want)
;~ 	$1               - use the first captured group - we only have one in this case
;■■■
;~ 	ProgressOn($PROG_TITLE & $PROG_VERSION, "Scan des dossiers: [Bac*20*]", "", Default, Default, 1)
;~ 	ProgressSet(Round($n/$Liste[0]*100), "[" & Round($n/$Liste[0]*100) & "%] " & "Vérif. de : " & StringRegExpReplace($File_Name, "^.*\\", ""))

;■■■

;■■■


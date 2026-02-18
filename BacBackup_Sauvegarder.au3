#NoTrayIcon
#Region ;**** Directives AutoIt3Wrapper ****
#AutoIt3Wrapper_Run_Au3Stripper=y
;~ #Au3Stripper_Parameters=/rm /mo /sf /sv
#Au3Stripper_Parameters=/rm /sf /sv
#AutoIt3Wrapper_UseUpx=n
#EndRegion

#Region ;**** Métadonnées de l'application ****
#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup - Agent de sauvegarde)
#pragma compile(FileVersion, 2.5.26.218)
#pragma compile(ProductVersion, 2.5.26.218)
#pragma compile(ProductName, BacBackup)
#pragma compile(InternalName, BacBackup_Sauvegarder)
#pragma compile(OriginalFilename, BacBackup_Sauvegarder.exe)
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
#pragma compile(Out, Installer\Files\BacBackup_Sauvegarder.exe)
#EndRegion

#include <WinAPIFiles.au3>
#include <Array.au3>
#include <File.au3>
#include <Misc.au3>
#include "include\Toast.au3"  ; https://www.autoitscript.com/forum/topic/108445-how-to-make-toast-new-version-2-aug-18/
#include "Utils.au3"

If $CMDLINE[0] < 2 Then
	Exit
EndIf

If _Singleton("BacBackup_Sauvegarder_Mutex", 1) = 0 Then Exit
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@         initialisation           @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Global $PasDeDossiers = 0 ;
Global $iPasDeModifications = 0 ;
Global $sMsgCheminsSauves = "Dossiers Sauvegardés:" & @CRLF
Global $NbOperationsCopie = 0
Global $sCheminDossierSession = $CMDLINE[2] & "\"
Global $sCheminDossierTemp = StringRegExpReplace($CMDLINE[2], '^(.*\\)[^\\]+\\[^\\]+$', '$1Tmp\\')
Global $sIniFilePath = StringRegExpReplace($CMDLINE[2], '^(.*\\)[^\\]+$', '$1BacBackup.ini')
;~ MsgBox($MB_SYSTEMMODAL, '$sCheminDossierSession', $sCheminDossierSession, 360)
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Début Programme Principal    @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;~ VerifierOneInstance()
Init()

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Fin Programme Principal    @@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Func Init()
;~ 	Sauvegarder()
;~ 	AfficherMsg()
	If $CMDLINE[0] Then
		Select
			Case StringInStr($CMDLINE[1], "normale") ;normale
				Sauvegarder()
			Case StringInStr($CMDLINE[1], "forcee") ;forcée
				Sauvegarder()
				AfficherMsg()
		EndSelect
	EndIf
EndFunc   ;==>Init

;#########################################################################################

Func AfficherMsg()
	Local $aRet[2], $Msg
;~ 	If $CmdLine[0] = 0 Then
;~ 		Exit
;~ 	EndIf
	If $PasDeDossiers = 0 Then
		$Msg = "Aucun dossier à sauvegarder !!" & @CRLF & @CRLF
		$Msg &= "Veuillez créer le dossier Bac20xx" & @CRLF & "et y enregister votre travail"
		_Toast_Set(5, 0xFF4500, 0x1C1C1C, 0x1C1C1C, 0xFF4500, 12, "Tahoma")
		$aRet = _Toast_Show("res\Logo01.png", "BacBackup", $Msg, -10)
;~ 		ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
		_Toast_Hide()
		Exit
	EndIf

	If $iPasDeModifications = 0 Then
		$Msg = "Aucune modification depuis" & @CRLF
		$Msg &= "la dernière sauvegarde"
		_Toast_Set(5, 0xFF4500, 0x1C1C1C, 0x1C1C1C, 0xFF4500, 12, "Tahoma")
		$aRet = _Toast_Show("res\Logo01.png", "BacBackup", $Msg, -5)
;~ 		ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
		_Toast_Hide()
		Exit
	Else
		_Toast_Set(4, 0xFF4500, 0x1C1C1C, 0x1C1C1C, 0xFF4500, 12, "Tahoma")
		$aRet = _Toast_Show("res\Logo01.png", "BacBackup", $sMsgCheminsSauves, -10, True, True)
;~ 		ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
		_Toast_Hide()
	EndIf
EndFunc   ;==>AfficherMsg

;#########################################################################################

Func Sauvegarder()
    ; On passe la fonction de nettoyage de chemin en paramètre ou on gère le type en interne
    _TraiterListeDossiers(VerifDossiersTravailEleves(), "Standard")
    _TraiterListeDossiers(VerifDossiersSurBureau(), "Bureau")
    _TraiterListeDossiers(VerifEasyPHPwww(), "Www")
    _TraiterListeDossiers(VerifEasyPHPdata(), "Data")
EndFunc

Func _TraiterListeDossiers($aDossiers, $sType)
    If Not IsArray($aDossiers) Or $aDossiers[0] = 0 Then Return

    For $x = 1 To $aDossiers[0]
        $NbOperationsCopie += 1
        Local $DossierSrc, $DossierBK, $CheminBK

        ; Déterminer le chemin source selon le type
        Switch $sType
            Case "Standard"
                $DossierSrc = StringTrimLeft($aDossiers[$x], 3)
            Case "Bureau"
                $DossierSrc = _FineBureauPath($aDossiers[$x])
            Case "Www"
                $DossierSrc = _FineWwwPath($aDossiers[$x])
            Case "Data"
                $DossierSrc = _FineDataPath($aDossiers[$x])
        EndSwitch

        $DossierBK = $DossierSrc
        $CheminBK = $sCheminDossierTemp & $DossierBK

        ; Copie et création du lien
        DirCopy($aDossiers[$x], $CheminBK, 1)
        If Not FileExists($CheminBK) Then
            ContinueLoop
        EndIf
		_LienVersDossier($aDossiers[$x], $CheminBK)


        ; Compression
        Local $Num = _IncrementerNum($DossierBK)
        Local $Dest = $sCheminDossierSession & $DossierBK & "___" & $Num & ".7z"
        Local $Src = $CheminBK & "\"

        Local $iResult = RunWait(@ScriptDir & '\7za.exe a "' & $Dest & '" "' & $Src & '" -t7z -r -mx=5', @ScriptDir, @SW_HIDE)
        If $iResult = 0 Then ; Succès
			; Mise à jour des messages et compteurs
			$sMsgCheminsSauves &= @CRLF & '"' & $DossierBK & '"'
			$iPasDeModifications += 1
        EndIf
	Next
EndFunc

;#########################################################################################

Func VerifDossiersTravailEleves()
	Local $DossierTravail = _DossiersTravailEleves() ;
	Local $Liste[1] = [0] ;
	If Not IsArray($DossierTravail) Then Return $Liste

	$PasDeDossiers += 1
	Local $aFldr_info, $iFldrSize, $iFilesCountInFldr
	For $i = 1 To $DossierTravail[0]
		;Si dossier vide, on passe
		$aFldr_info = DirGetSize($DossierTravail[$i], 1)
		$iFldrSize = $aFldr_info[0]
		$iFilesCountInFldr = $aFldr_info[1]
		If $iFilesCountInFldr = 0 And $iFldrSize = 0 Then ContinueLoop
		;-----
		$DossierBK = StringTrimLeft($DossierTravail[$i], 3)
		$Numero = IniRead($sIniFilePath, "DerniersDossiers", $DossierBK, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $DossierTravail[$i])

			ContinueLoop
		EndIf

		$Kes = _FileListToArrayRec($DossierTravail[$i], "*", 1, 1, 0, 2)
		If IsArray($Kes) Then
			For $x = 1 To $Kes[0]
;~ If File does not exist then copy the file and create directory if required
				$Tmp = StringTrimLeft($Kes[$x], 3) ;  "C:\Bac2020\123456\devoir.pas" >>> "Bac2020\123456\devoir.pas"
				$Tmp = StringTrimLeft($Tmp, StringInStr($Tmp, '\')) ; "Bac2020\123456\devoir.pas" >>> "123456\devoir.pas"
				$FichierBCK = $sCheminDossierTemp & $DossierBK & '\' & $Tmp
				If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $DossierTravail[$i])
					;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
					$CheminBK = $sCheminDossierTemp & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
					If FileExists($CheminBK) Then
						DirRemove($CheminBK, 1)
					EndIf
					;--------------------- Fin Compression & Suppression du dossier src --------------------------------------------

					ExitLoop
				EndIf
			Next
		EndIf
	Next
	Return $Liste
EndFunc   ;==>VerifDossiersTravailEleves

;#########################################################################################

Func VerifDossiersSurBureau()
	Local $DossierTravail = _DossiersSurBureau() ;
	Local $Liste[1] = [0] ;
	If Not IsArray($DossierTravail) Then Return $Liste

	$PasDeDossiers += 1
	Local $aFldr_info, $iFldrSize, $iFilesCountInFldr
	For $i = 1 To $DossierTravail[0]
		;Si dossier vide, on passe
		$aFldr_info = DirGetSize($DossierTravail[$i], 1)
		$iFldrSize = $aFldr_info[0]
		$iFilesCountInFldr = $aFldr_info[1]
		If $iFilesCountInFldr = 0 And $iFldrSize = 0 Then ContinueLoop
		;-----
		$DossierBK = _FineBureauPath($DossierTravail[$i])

		$Numero = IniRead($sIniFilePath, "DerniersDossiers", $DossierBK, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $DossierTravail[$i])

			ContinueLoop
		EndIf

		$Kes = _FileListToArrayRec($DossierTravail[$i], "*", 1, 1, 0, 2)
		If IsArray($Kes) Then
			For $x = 1 To $Kes[0]
				$Tmp = StringReplace($Kes[$x], _GetRealDesktopPath() & '\', '')
				$Tmp = StringTrimLeft($Tmp, StringInStr($Tmp, '\'))
				$FichierBCK = $sCheminDossierTemp & $DossierBK & '\' & $Tmp
				If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $DossierTravail[$i])
					;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
					$CheminBK = $sCheminDossierTemp & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
					If FileExists($CheminBK) Then
						DirRemove($CheminBK, 1)
					EndIf
					;--------------------- Fin Compression & Suppression du dossier src --------------------------------------------

					ExitLoop
				EndIf
			Next
		EndIf
	Next
	Return $Liste
EndFunc   ;==>VerifDossiersSurBureau

;#########################################################################################

Func VerifEasyPHPwww()
	Local $EasyPHPwww = DossiersEasyPHPwww() ;
	If $EasyPHPwww[0] <> 0 Then
		$PasDeDossiers += 1
	EndIf

	Local $Liste[1] = [0] ;

	For $i = 1 To $EasyPHPwww[0]
;~ 		ConsoleWrite($EasyPHPwww[$i] & @CRLF)
		If Not _WwwFolderHasContent($EasyPHPwww[$i]) Then ContinueLoop
		$DossierBK_FinePath = _FineWwwPath($EasyPHPwww[$i])
		$Numero = IniRead($sIniFilePath, "DerniersDossiers", $DossierBK_FinePath, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $EasyPHPwww[$i])

			ContinueLoop
		EndIf
		;$DossierBK=$DossierBK_SansBackSlash
;~ 		ConsoleWrite("! $EasyPHPwww[$i]: " & $EasyPHPwww[$i] & @CRLF)
		$Kes = _FileListToArrayRec($EasyPHPwww[$i], "*|wampthemes;phpinfo.php|wampthemes", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_FASTSORT,  $FLTAR_FULLPATH)
		If IsArray($Kes) Then
			For $x = 1 To $Kes[0]
				$Tmp = StringReplace($Kes[$x], $EasyPHPwww[$i] & "\", "")
				$FichierBCK = $sCheminDossierTemp & $DossierBK_FinePath & '\' & $Tmp
				If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
;~ 					MsgBox($MB_SYSTEMMODAL, '', $Kes[$x] & @CRLF & $FichierBCK)
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $EasyPHPwww[$i])
					;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
					$CheminBK = $sCheminDossierTemp & $DossierBK_FinePath ;Dossier "X:\sauvegardes\Tmp\..."
					If FileExists($CheminBK) Then
						DirRemove($CheminBK, 1)
					EndIf
					;--------------------- Fin Compression & Suppression du dossier src --------------------------------------------

					ExitLoop
				EndIf
;~ 					MsgBox($MB_SYSTEMMODAL, '', $Kes[$x] & @
			Next
		EndIf
	Next
	Return $Liste
EndFunc   ;==>VerifEasyPHPwww

;#########################################################################################

Func VerifEasyPHPdata()
	Local $EasyPHPdata = DossiersEasyPHPdata() ;

	Local $Liste[1] = [0] ;
	If Not IsArray($EasyPHPdata) Then Return $Liste


	$PasDeDossiers += 1

	For $i = 1 To $EasyPHPdata[0]
		$DossierBK_FinePath = _FineDataPath($EasyPHPdata[$i])
		$Numero = IniRead($sIniFilePath, "DerniersDossiers", $DossierBK_FinePath, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $EasyPHPdata[$i])

			ContinueLoop
		EndIf

		$TmpDossiers = _FileListToArrayRec($EasyPHPdata[$i], "*|phpmyadmin;mysql;performance_schema;sys;cdcol;webauth|", 2, 0, 2, 2)
		If Not IsArray($TmpDossiers) Then ContinueLoop
		$TmpDossiers[0] = UBound($TmpDossiers) - 1

		For $j = 1 To $TmpDossiers[0]
			$Kes = _FileListToArrayRec($TmpDossiers[$j], "*", 1, 1, 2, 2)
			Local $iLocalModif = 0
			;====================================================================
			If IsArray($Kes) Then
				For $x = 1 To $Kes[0]
					;~ If File does not exist then copy the file and create directory if required
					$Tmp = StringTrimLeft($Kes[$x], StringInStr($Kes[$x], '\data')) ;
					$Tmp = StringTrimLeft($Tmp, StringInStr($Tmp, '\')) ;
					$FichierBCK = $sCheminDossierTemp & $DossierBK_FinePath & '\' & $Tmp
					If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
						$Liste[0] += 1 ;
						_ArrayAdd($Liste, $EasyPHPdata[$i])
						;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
						$CheminBK = $sCheminDossierTemp & $DossierBK_FinePath ;Dossier "X:\sauvegardes\Tmp\..."
						If FileExists($CheminBK) Then
							DirRemove($CheminBK, 1)
						EndIf
						;--------------------- Fin Compression & Suppression du dossier src --------------------------------------------

						$iLocalModif += 1
						ExitLoop
					EndIf
				Next
				If $iLocalModif Then ExitLoop
			EndIf
		Next
	Next
	Return $Liste
EndFunc   ;==>VerifEasyPHPdata

;#########################################################################################

Func _FineDataPath($sDataPath)
	$sDataPath = StringTrimLeft($sDataPath, 3) ;
;~ 	$sDataPath = StringReplace($sDataPath, "Program Files (x86)", "{pf}")
;~ 	$sDataPath = StringReplace($sDataPath, "Program Files", "{pf}")
	$sDataPath = StringRegExpReplace($sDataPath, "\\bin\\.*", "", 0)
	$sDataPath = StringRegExpReplace($sDataPath, "\\apps\\.*", "", 0)
	$sDataPath = StringRegExpReplace($sDataPath, "\\mysql.*", "", 0)
	$sDataPath = StringRegExpReplace($sDataPath, "\\mariadb.*", "", 0)
;~ 	$sDataPath = StringRegExpReplace($sDataPath, "\\eds-binaries.*", "", 0)
	$sDataPath &= "\{data}"
	$sDataPath = StringReplace($sDataPath, "\", "-")
	Return $sDataPath
EndFunc   ;==>_FineDataPath

;#########################################################################################

Func _FineWwwPath($sDataPath)
    ; Exemples d'entrée :
    ; "C:\xampp_lite_8_4\www"
    ; "D:\xampp\htdocs"

    ; Supprimer la lettre de lecteur et ":\"
    $sDataPath = StringTrimLeft($sDataPath, 3)

    ; Remplacer le dernier "\" par "-{"
    Local $iPos = StringInStr($sDataPath, "\", 0, -1)
    If $iPos > 0 Then
        $sDataPath = StringLeft($sDataPath, $iPos - 1) & "-{" & StringTrimLeft($sDataPath, $iPos) & "}"
    EndIf

    ; Remplacer les "\" restants par "-"
    $sDataPath = StringReplace($sDataPath, "\", "-")

    Return $sDataPath
EndFunc   ;==>_FineWwwPath
;#########################################################################################

Func _FineBureauPath($sDataPath)
	$sDataPath = StringReplace($sDataPath, _GetRealDesktopPath(), "{Bureau}")
	$sDataPath = StringReplace($sDataPath, "\", "-")
	Return $sDataPath
EndFunc   ;==>_FineBureauPath

;#########################################################################################

Func VerifierOneInstance()
	Local $list = ProcessList()
	Local $sMsg, $aRet[2]
	For $i = 1 To $list[0][0]
		If $list[$i][0] = @ScriptName Then
			If $list[$i][1] <> @AutoItPID Then
				Exit
			EndIf
		EndIf
	Next
EndFunc   ;==>VerifierOneInstance

;#########################################################################################

Func _LienVersDossier($DossierSrc, $CheminLnk)
;~ 	$CheminLnk &= "\" & StringRegExpReplace($DossierSrc, "^.*\\", "") & ".lnk"
	$CheminLnk &= "\dossier d'origine.lnk"
	FileCreateShortcut($DossierSrc, $CheminLnk, Default, Default, "Aller vers """ & $DossierSrc & """", @ScriptDir & "\res\dossier.ico", "", "0", @SW_SHOWMAXIMIZED)
EndFunc   ;==>_LienVersDossier

;#########################################################################################

Func _IncrementerNum($DossierBK)
    Local $Num = IniRead($sIniFilePath, "DerniersDossiers", $DossierBK, "0")

    ; Validation et réinitialisation si nécessaire
    If Not StringIsInt($Num) Or $Num > 999 Or $Num < 0 Then $Num = 0

    $Num += 1

    ; Formatage sur 3 chiffres
    $Num = StringFormat("%03d", $Num)

    IniWrite($sIniFilePath, "DerniersDossiers", $DossierBK, $Num)
    Return $Num
EndFunc
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

;~ _ArrayDisplay($ListeDossiersDansData, $Kes[$x],"",32,Default ,"Avant Suppression")
;~ MsgBox($MB_SYSTEMMODAL, 'dossier', $www, 360)
;~ _ArrayDisplay($Liste, 'BacBackup 1.0.0',"",32,Default ,"Liste de Dossiers/Fichiers Surveillés")

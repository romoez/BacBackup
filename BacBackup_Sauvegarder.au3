#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_Compression=4
;~ #AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup Auto-Sauvegarde)
#pragma compile(FileVersion, 2.2.3.516, 2.2.3.516) ; Le dernier paramètre est optionnel
#pragma compile(ProductName, BacBackup)
#pragma compile(ProductVersion, 2.2.3.516)

#pragma compile(LegalCopyright, 2016-2022 © La Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments,'BacBackup - Module de Sauvegarde')
#pragma compile(Out, BacBackup_Sauvegarder.exe)
#pragma compile(CompanyName, La Communauté Tunisienne des Enseignants d'Informatique)

#NoTrayIcon

#include <WinAPIFiles.au3>
#include <Array.au3>
#include <File.au3>
#include "Utils.au3"
#include "include\Toast.au3"  ; https://www.autoitscript.com/forum/topic/108445-how-to-make-toast-new-version-2-aug-18/

Global $PasDeDossiers = 0 ;
Global $PasDeModifications = 0 ;
Global $CheminsSauves = "Dossiers Sauvegardés:" & @CRLF
Global $NbOperationsCopie = 0
Global $UserLocal = _GetUserLocal()

$DossierSauvegardes = "Sauvegardes"

Global $Lecteur = LecteurSauvegarde()

If Not FileExists($Lecteur & $DossierSauvegardes) Then
	DirCreate($Lecteur & $DossierSauvegardes)
EndIf
;~ Dossier Captures d'écran
If Not FileExists($Lecteur & $DossierSauvegardes & "\BacBackup") Then
	_UnLockFolder($Lecteur & $DossierSauvegardes)
	DirCreate($Lecteur & $DossierSauvegardes & "\BacBackup")
EndIf

;~ Dossier Tmp
If Not FileExists($Lecteur & $DossierSauvegardes & "\Tmp") Then
	_UnLockFolder($Lecteur & $DossierSauvegardes)
	DirCreate($Lecteur & $DossierSauvegardes & "\Tmp")
EndIf

FileSetAttrib($Lecteur & $DossierSauvegardes, "+SH")
_LockFolder($Lecteur & $DossierSauvegardes)


;~ Sous Dossier Captures d'écran
Global $DossierSession = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "DossierSession", "/^_^\")
If Not FileExists($Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession) Then
	$Tmp = StringLeft($DossierSession, 3)
;~    MsgBox ( 0, "", $Tmp  )
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
	DirCreate($Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession)
EndIf

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Début Programme Principal    @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

VerifierOneInstance()
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
		ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
		_Toast_Hide()
		Exit
	EndIf

	If $PasDeModifications = 0 Then
		$Msg = "Aucune modification depuis" & @CRLF
		$Msg &= "la dernière sauvegarde"
		_Toast_Set(5, 0xFF4500, 0x1C1C1C, 0x1C1C1C, 0xFF4500, 12, "Tahoma")
		$aRet = _Toast_Show("res\Logo01.png", "BacBackup", $Msg, -5)
		ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
		_Toast_Hide()
		Exit
	Else
		_Toast_Set(4, 0xFF4500, 0x1C1C1C, 0x1C1C1C, 0xFF4500, 12, "Tahoma")
		$aRet = _Toast_Show("res\Logo01.png", "BacBackup", $CheminsSauves, -10, True, True)
		ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
		_Toast_Hide()
	EndIf
EndFunc   ;==>AfficherMsg

;#########################################################################################

Func Sauvegarder()
;~ -----------
	$Kes = VerifDossiersTravailEleves()
	If $Kes[0] > 0 Then
		For $x = 1 To $Kes[0]
			$NbOperationsCopie += 1
			$DossierSrc = StringTrimLeft($Kes[$x], 3) ;
			$DossierBK = $DossierSrc ;& "____" & $Num & '___' & @HOUR & "h" & @MIN
			$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
			DirCopy($Kes[$x], $CheminBK, 1)
			_LienVersDossier($Kes[$x], $CheminBK)
			$CheminsSauves &= @CRLF & """" & $DossierBK & """"
			$PasDeModifications += 1
			$Num = _IncrementerNum($DossierBK)
			$Dest = $Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession & "\" & $DossierBK & "___" & $Num & ".7z"
			$Src = $CheminBK & "\"
			RunWait(@ComSpec & ' /C 7za.exe a "' & $Dest & '" "' & $Src & '" -t7z -r', @ScriptDir, @SW_HIDE)
		Next
	EndIf
;~ -----------
	$Kes = VerifDossiersSurBureau()
	If $Kes[0] > 0 Then
		For $x = 1 To $Kes[0]
			$NbOperationsCopie += 1
			$DossierSrc = _FineBureauPath($Kes[$x]) ;
			$DossierBK = $DossierSrc ;& "____" & $Num & '___' & @HOUR & "h" & @MIN
			$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
			DirCopy($Kes[$x], $CheminBK, 1)
			_LienVersDossier($Kes[$x], $CheminBK)
			$CheminsSauves &= @CRLF & """" & $DossierBK & """"
			$PasDeModifications += 1
			$Num = _IncrementerNum($DossierBK)
			$Dest = $Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession & "\" & $DossierBK & "___" & $Num & ".7z"
			$Src = $CheminBK & "\"
			RunWait(@ComSpec & ' /C 7za.exe a "' & $Dest & '" "' & $Src & '" -t7z -r', @ScriptDir, @SW_HIDE)
		Next
	EndIf
;~ -----------
	$Kes = VerifTPW()
	If $Kes[0] > 0 Then
		For $x = 1 To $Kes[0]
			$NbOperationsCopie += 1
			$DossierSrc = StringTrimLeft($Kes[$x], 3) ;
			$DossierBK = $DossierSrc ;& "____" & $Num & '___' & @HOUR & "h" & @MIN
			$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
			DirCreate($CheminBK)
			FileCopy($Kes[$x] & '\*.pas', $CheminBK, 1)
			_LienVersDossier($Kes[$x], $CheminBK)
			$CheminsSauves &= @CRLF & """" & $DossierBK & """"
			$PasDeModifications += 1
			$Num = _IncrementerNum($DossierBK)
			$Dest = $Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession & "\" & $DossierBK & "___" & $Num & ".7z"
			$Src = $CheminBK & "\"
			RunWait(@ComSpec & ' /C 7za.exe a "' & $Dest & '" "' & $Src & '" -t7z -r', @ScriptDir, @SW_HIDE)
		Next
	EndIf
;~ -----------
	$Kes = VerifEasyPHPwww()
	If $Kes[0] > 0 Then
		For $x = 1 To $Kes[0]
			$NbOperationsCopie += 1
			$DossierSrc = _FineWwwPath($Kes[$x])
			$DossierBK = $DossierSrc ;& "____" & $Num & '___' & @HOUR & "h" & @MIN
			$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
			DirCopy($Kes[$x], $CheminBK, 1)
			_LienVersDossier($Kes[$x], $CheminBK)
			$CheminsSauves &= @CRLF & """" & $DossierBK & """"
			$PasDeModifications += 1
			$Num = _IncrementerNum($DossierBK)
			$Dest = $Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession & "\" & $DossierBK & "___" & $Num & ".7z"
			$Src = $CheminBK & "\"
			RunWait(@ComSpec & ' /C 7za.exe a "' & $Dest & '" "' & $Src & '" -t7z -r', @ScriptDir, @SW_HIDE)
		Next
	EndIf
;~ -----------
	$Kes = VerifEasyPHPdata()
	If $Kes[0] > 0 Then
		For $x = 1 To $Kes[0]
			$DossierSrc = _FineDataPath($Kes[$x])
			$DossierBK = $DossierSrc ;& "____" & $Num & '___' & @HOUR & "h" & @MIN
			$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
			$ListeDossiersDansData = _FileListToArrayRec($Kes[$x], "*||phpmyadmin;mysql;performance_schema", 2, 0, 2, 0) ;Liste de Dossiers
			_ArrayDelete($ListeDossiersDansData, _ArraySearch($ListeDossiersDansData, "phpmyadmin"))
			_ArrayDelete($ListeDossiersDansData, _ArraySearch($ListeDossiersDansData, "mysql"))
			_ArrayDelete($ListeDossiersDansData, _ArraySearch($ListeDossiersDansData, "performance_schema"))
			_ArrayDelete($ListeDossiersDansData, _ArraySearch($ListeDossiersDansData, "sys"))
			$ListeDossiersDansData[0] = UBound($ListeDossiersDansData) - 1
			If $ListeDossiersDansData[0] > 0 Then
				$NbOperationsCopie += 1
				$CheminsSauves &= @CRLF & """" & $DossierBK & """"
				$PasDeModifications += 1
				For $cpt = 1 To $ListeDossiersDansData[0]
					DirCreate($CheminBK & '\' & $ListeDossiersDansData[$cpt])
					DirCopy($Kes[$x] & '\' & $ListeDossiersDansData[$cpt], $CheminBK & '\' & $ListeDossiersDansData[$cpt], 1)

				Next
				_LienVersDossier($Kes[$x], $CheminBK)
				$Fichiersibdata = _FileListToArrayRec($Kes[$x], "ibdata*||", 1, 0, 0, 0) ;Liste de Fichiers sur la racine du Dossier "daa"

				If IsArray($Fichiersibdata) Then
					For $cpt = 1 To $Fichiersibdata[0]
						FileCopy($Kes[$x] & '\' & $Fichiersibdata[$cpt], $CheminBK, $FC_OVERWRITE + $FC_CREATEPATH)
					Next
				EndIf
				$Num = _IncrementerNum($DossierBK)
				$Dest = $Lecteur & $DossierSauvegardes & "\BacBackup\" & $DossierSession & "\" & $DossierBK & "___" & $Num & ".7z"
				$Src = $CheminBK & "\"
				RunWait(@ComSpec & ' /C 7za.exe a "' & $Dest & '" "' & $Src & '" -t7z -r', @ScriptDir, @SW_HIDE)
			EndIf
		Next
	EndIf
EndFunc   ;==>Sauvegarder

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
		$Numero = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK, "-111")
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
				$FichierBCK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK & '\' & $Tmp
				If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $DossierTravail[$i])
					;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
					$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
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
		$Numero = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK, "-111")
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
				$FichierBCK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK & '\' & $Tmp
				If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $DossierTravail[$i])
					;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
					$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
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

Func VerifTPW()
	Local $TPW = DossiersTPW() ;

	If $TPW[0] <> 0 Then
		$PasDeDossiers += 2
	EndIf
	Local $Liste[1] = [0] ;

	For $i = 1 To $TPW[0]
		$DossierBK = StringTrimLeft($TPW[$i], 3)
		$Kes = _FileListToArray($TPW[$i], "*.pas", 1, True)

		If Not IsArray($Kes) Then ContinueLoop

		$Numero = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $TPW[$i])

			ContinueLoop
		EndIf
		For $x = 1 To $Kes[0]
			$Tmp = StringTrimLeft($Kes[$x], 3) ;
			$Tmp = StringTrimLeft($Tmp, StringInStr($Tmp, '\')) ;

			$FichierBCK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK & '\' & $Tmp
			If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
				$Liste[0] += 1 ;
				_ArrayAdd($Liste, $TPW[$i])
				;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
				$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK ;Dossier "X:\sauvegardes\Tmp\..."
				If FileExists($CheminBK) Then
					DirRemove($CheminBK, 1)
				EndIf
				;--------------------- Fin Compression & Suppression du dossier src --------------------------------------------

				ExitLoop
			EndIf
		Next
	Next
	Return $Liste
EndFunc   ;==>VerifTPW

;#########################################################################################

Func VerifEasyPHPwww()
	Local $EasyPHPwww = DossiersEasyPHPwww() ;
	If $EasyPHPwww[0] <> 0 Then
		$PasDeDossiers += 1
	EndIf

	Local $Liste[1] = [0] ;

	For $i = 1 To $EasyPHPwww[0]
		$DossierBK_FinePath = _FineWwwPath($EasyPHPwww[$i])
		$Numero = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK_FinePath, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $EasyPHPwww[$i])

			ContinueLoop
		EndIf
		;$DossierBK=$DossierBK_SansBackSlash
		$Kes = _FileListToArrayRec($EasyPHPwww[$i], "*|wampthemes;phpinfo.php|wampthemes", 1, 1, 2, 2)
		If IsArray($Kes) Then
			For $x = 1 To $Kes[0]
				If StringInStr($Kes[$x], 'www\') Then
					$Tmp = StringTrimLeft($Kes[$x], StringInStr($Kes[$x], 'www\') + 3) ; stringlen('www') = 3
				ElseIf StringInStr($Kes[$x], 'htdocs\') Then
					$Tmp = StringTrimLeft($Kes[$x], StringInStr($Kes[$x], 'htdocs\') + 6) ; stringlen('htdocs') = 6
				EndIf
				$FichierBCK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK_FinePath & '\' & $Tmp
				If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
;~ 					MsgBox($MB_SYSTEMMODAL, '', $Kes[$x] & @CRLF & $FichierBCK)
					$Liste[0] += 1 ;
					_ArrayAdd($Liste, $EasyPHPwww[$i])
					;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
					$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK_FinePath ;Dossier "X:\sauvegardes\Tmp\..."
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
EndFunc   ;==>VerifEasyPHPwww

;#########################################################################################

Func VerifEasyPHPdata()
	Local $EasyPHPdata = DossiersEasyPHPdata() ;

	Local $Liste[1] = [0] ;
	If Not IsArray($EasyPHPdata) Then Return $Liste


	$PasDeDossiers += 1

	For $i = 1 To $EasyPHPdata[0]
		$DossierBK_FinePath = _FineDataPath($EasyPHPdata[$i])
		$Numero = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK_FinePath, "-111")
		If $Numero = "-111" Then
			$Liste[0] += 1 ;
			_ArrayAdd($Liste, $EasyPHPdata[$i])

			ContinueLoop
		EndIf

		$TmpDossiers = _FileListToArrayRec($EasyPHPdata[$i], "*||phpmyadmin;mysql;performance_schema", 2, 0, 2, 2)
		If Not IsArray($TmpDossiers) Then ContinueLoop
		_ArrayDelete($TmpDossiers, _ArraySearch($TmpDossiers, $EasyPHPdata[$i] & "\" & "phpmyadmin"))
		_ArrayDelete($TmpDossiers, _ArraySearch($TmpDossiers, $EasyPHPdata[$i] & "\" & "mysql"))
		_ArrayDelete($TmpDossiers, _ArraySearch($TmpDossiers, $EasyPHPdata[$i] & "\" & "performance_schema"))
		_ArrayDelete($TmpDossiers, _ArraySearch($TmpDossiers, $EasyPHPdata[$i] & "\" & "sys"))
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
					$FichierBCK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK_FinePath & '\' & $Tmp
					If (FileExists($FichierBCK) = 0) Or _IsFileDiff($Kes[$x], $FichierBCK) Then
						$Liste[0] += 1 ;
						_ArrayAdd($Liste, $EasyPHPdata[$i])
						;--------------------- Début Compression & Suppression du dossier src --------------------------------------------
						$CheminBK = $Lecteur & $DossierSauvegardes & '\Tmp\' & $DossierBK_FinePath ;Dossier "X:\sauvegardes\Tmp\..."
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
	$sDataPath = StringReplace($sDataPath, "Program Files (x86)", "{pf}")
	$sDataPath = StringReplace($sDataPath, "Program Files", "{pf}")
	$sDataPath = StringRegExpReplace($sDataPath, "\\bin\\.*", "", 0)
	$sDataPath = StringRegExpReplace($sDataPath, "\\mysql.*", "", 0)
	$sDataPath = StringRegExpReplace($sDataPath, "\\eds-binaries.*", "", 0)
	$sDataPath &= "\{data}"
	$sDataPath = StringReplace($sDataPath, "\", "-")
	Return $sDataPath
EndFunc   ;==>_FineDataPath

;#########################################################################################

Func _FineWwwPath($sDataPath)
	$sDataPath = StringTrimLeft($sDataPath, 3) ;
	$sDataPath = StringReplace($sDataPath, "Program Files (x86)", "{pf}")
	$sDataPath = StringReplace($sDataPath, "Program Files", "{pf}")
	$sDataPath = StringRegExpReplace($sDataPath, "\\eds-www.*", "", 0)
	$sDataPath = StringRegExpReplace($sDataPath, "\\www.*", "", 0)
	If (StringRight($sDataPath, 6) <> 'htdocs') Then
		$sDataPath &= "\{www}"
	EndIf
	$sDataPath = StringReplace($sDataPath, "\", "-")
	Return $sDataPath
EndFunc   ;==>_FineWwwPath

;#########################################################################################

Func _FineBureauPath($sDataPath)
	$sDataPath = StringReplace($sDataPath, @DesktopDir, "{Bureau}")
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
	$Num = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK, "-111")
	If $Num = "-111" Or StringIsInt($Num) = 0 Or $Num > 1000 Or $Num < 0 Then $Num = 0
	$Num = $Num + 1 ;
	$Num = "00" & $Num
	$Num = StringRight($Num, 3)
	IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "DerniersDossiers", $DossierBK, $Num)
	Return $Num
EndFunc   ;==>_IncrementerNum

;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
;■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■

;~ _ArrayDisplay($ListeDossiersDansData, $Kes[$x],"",32,Default ,"Avant Suppression")
;~ MsgBox($MB_SYSTEMMODAL, 'dossier', $www, 360)
;~ _ArrayDisplay($Liste, 'BacBackup 1.0.0',"",32,Default ,"Liste de Dossiers/Fichiers Surveillés")

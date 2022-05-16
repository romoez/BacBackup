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

#pragma compile(LegalCopyright, © La Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments,'BacBackup - Fenêtre principale')
#pragma compile(Out, BacBackup_Interface.exe)
#pragma compile(CompanyName, La Communauté Tunisienne des Enseignants d'Informatique)

#NoTrayIcon

#include <WinAPIFiles.au3>
#include <ListViewConstants.au3>
#include <File.au3>
#include <Array.au3>
#include <GuiConstants.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <GuiListView.au3>
#include "Utils.au3"
#include "include\StringSize.au3"  ; https://www.autoitscript.com/forum/topic/114034-stringsize-m23-new-version-16-aug-11/
#include "include\GUIHyperLink.au3"  ; https://www.autoitscript.com/forum/topic/126934-guihyperlink-create-hyperlink-controls/

#Region GLOBAL VARIABLES
Global $iW = 640, $iH = 400, $iT = 52, $iB = 52, $iLeftWidth = 150, $iGap = 10, $hMainGUI
#EndRegion GLOBAL VARIABLES

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Début Programme Principal    @@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

_KillOtherScript()
$CheminSauve = ""
If $CMDLINE[0] Then
	$CheminSauve = $CMDLINE[1]
EndIf
If Not FileExists($CheminSauve) Then
	$Lecteur = LecteurSauvegarde()
	$CheminSauve = StringUpper($Lecteur) & "Sauvegardes\BacBackup"
EndIf

$DossierSession = IniRead($CheminSauve & "\BacBackup.ini", "Params", "DossierSession", "")
$Prog_Version = FileGetVersion(@ScriptFullPath)

_MainGui()

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Fin Programme Principal    @@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Func _MainGui()
	Local $nMsg, $aPos
	Local $iLinks = 5
	Local $sMainGuiTitle = "BacBackup " & $Prog_Version
	Local $sHeader = ""
	;	Local $sFooter = "CPU >> "& @CPUArch &@TAB &"#"&@TAB &"Version de Windows >> "&@OSVersion&@TAB&"    #" &@TAB &"Dossier Système >> "&@WindowsDir
	Local $aLink[$iLinks], $aPanel[$iLinks]
	$aLink[0] = $iLinks - 1
	$aPanel[0] = $iLinks - 1


	;***************************************************************************************************
	$hMainGUI = GUICreate($sMainGuiTitle, $iW, $iH, -1, -1)

	GUICtrlCreateLabel($sHeader, 52, 8, $iW - 56, 32, $SS_CENTERIMAGE)

	GUICtrlSetFont(-1, 14, 800, 0, "Arial", 5)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)

	$Logo = GUICtrlCreateIcon("res/Logo01-Interface.ico", -1, 6, 6, 40, 40)
	;-----------------------------------
	$LogoText = GUICtrlCreateIcon("res/Txt.ico", -1, 56, 10, 100, 20)
	GUICtrlCreateLabel("Surveillance et sauvegarde automatique des dossiers de travail des élèves", 56, 35, 500)
	GUICtrlSetFont(-1, 9, 500, "", "Tahoma", 5)

	GUICtrlCreateLabel("", 0, $iT, $iW, 2, $SS_SUNKEN) ;separator
	GUICtrlCreateLabel("", $iLeftWidth, $iT + 2, 2, $iH - $iT - $iB - 2, $SS_SUNKEN) ;separator
	GUICtrlCreateLabel("", 150, $iH - $iB, $iW, 2, $SS_SUNKEN) ;separator
	GUICtrlCreateLabel("", 150, $iH - $iB, 2, 52, $SS_SUNKEN) ;separator
	;====================================================================
	;====================================================================
	Switch @MON
		Case 01
			$MON = "Janv" ;
		Case 02
			$MON = "Févr" ;
		Case 03
			$MON = "Mars" ;
		Case 04
			$MON = "Avr." ;
		Case 05
			$MON = "Mai" ;
		Case 06
			$MON = "Juin" ;
		Case 07
			$MON = "Juil" ;
		Case 08
			$MON = "Août" ;
		Case 09
			$MON = "Sept" ;
		Case 10
			$MON = "Oct." ;
		Case 11
			$MON = "Nov." ;
		Case 12
			$MON = "Déc." ;
	EndSwitch

	GUICtrlCreateLabel("Windows " & StringTrimLeft(@OSVersion, 4) & " " & (@OSArch = "X86" ? "32-bit" : "64-bit"), 5, $iH - 45, 140, 17, BitOR($SS_CENTER, $SS_CENTERIMAGE))
	GUICtrlSetFont(-1, 11, 400, 0, "Tahoma")
	GUICtrlCreateLabel(@MDAY & " " & $MON & " " & @YEAR, 5, $iH - 22, 140, 17, BitOR($SS_CENTER, $SS_CENTERIMAGE))
	GUICtrlSetFont(-1, 11, 600, 0, "Tahoma")

	GUICtrlCreateLabel("Dossier de Sauvegarde: ", 175, $iH - 40, 155, 30, BitOR($SS_LEFT, $SS_CENTERIMAGE))
	GUICtrlSetFont(-1, 11, 400, 0, "Tahoma")

	Global $GUI_Ouvrir_BasDePage = GUICtrlCreateLabel($CheminSauve, 330, $iH - 40, 355, 30, BitOR($SS_LEFT, $SS_CENTERIMAGE))
	GUICtrlSetTip(-1, "le dossier de Sauvegarde", "Cliquez pour ouvrir")
	GUICtrlSetCursor(-1, 0)
	GUICtrlSetFont(-1, 11, 500, 4, "Tahoma")
	GUICtrlSetColor(-1, 0x032EA5)


	;====================================================================
	;====================================================================

	;add links to the left side
	$aLink[1] = _AddNewLink("Dossiers Surveillés")
	$aLink[2] = _AddNewLink("Paramètres", 22)
	$aLink[3] = _AddNewLink("Aide", -155)
	$aLink[4] = _AddNewLink("À propos", -222)
	;and the corresponding GUI's
	$aPanel[1] = _AddNewPanel("Dossiers Surveillés")
	$aPanel[2] = _AddNewPanel("")
	$aPanel[3] = _AddNewPanel("Rapport...")
	$aPanel[4] = _AddNewPanel("À propos")

	;add some controls to the panels
	_AddControlsToPanel($aPanel[1])

	Global $GUI_ListeFichiers = GUICtrlCreateListView("N°|Dossiers", 9, 41, 470, 245, $LVS_REPORT, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
	_GUICtrlListView_SetColumnWidth($GUI_ListeFichiers, 1, $LVSCW_AUTOSIZE_USEHEADER)
	_AddControlsToPanel($aPanel[2])
	;Début *****************************************************************************************
	GUICtrlCreateGroup("Paramètres", 9, 11, 464, 165)
	GUICtrlSetFont(-1, 9.5, 800, 4, "Tahoma")

	Local $Marge = 30
	Local $Top = 28

	GUICtrlCreateLabel("Dossier de sauvegarde : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
	GUICtrlSetFont(-1, 9, 400) ;
	GUICtrlCreateInput($CheminSauve, 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, 0xFFFFFF)

	$Top += $Marge
	$IntervalleInterSauvegardes = IniRead($CheminSauve & "\BacBackup.ini", "Params", "IntervalleInterSauvegardesEnMinutes", "")

	GUICtrlCreateLabel("Intervalle inter-sauvegardes : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
	GUICtrlSetFont(-1, 9, 400) ;
	GUICtrlCreateInput($IntervalleInterSauvegardes & " minutes", 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, 0xFFFFFF)

	$Top += $Marge
	$IntervalleInterCaptures = IniRead($CheminSauve & "\BacBackup.ini", "Params", "IntervalleInterCapturesEnSecondes", "")

	GUICtrlCreateLabel("Intervalle inter-captures d'écran : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
	GUICtrlSetFont(-1, 9, 400) ;
	GUICtrlCreateInput($IntervalleInterCaptures & " secondes", 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, 0xFFFFFF)

	$Top += $Marge
	$TailleMaxDuDossierBacBackupEnGigaoctet = IniRead($CheminSauve & "\BacBackup.ini", "Params", "TailleMaxDuDossierBacBackupEnGigaoctet", "0")

	GUICtrlCreateLabel("Taille maximale du dossier de sauvegarde : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
	GUICtrlSetFont(-1, 9, 400) ;
	GUICtrlCreateInput($TailleMaxDuDossierBacBackupEnGigaoctet & " Go", 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, 0xFFFFFF)

	$Top += $Marge
	$NombreMaxDeDossiersDeSauve = IniRead($CheminSauve & "\BacBackup.ini", "Params", "NombreMaxDeDossiersDeSauve", "0")

	GUICtrlCreateLabel("Nombre maximal de sessions de sauvegarde : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
	GUICtrlSetFont(-1, 9, 400) ;
	GUICtrlCreateInput($NombreMaxDeDossiersDeSauve & " dossiers", 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, 0xFFFFFF)

	;============
	If FileExists($CheminSauve) Then
		GUICtrlCreateGroup("Données actuelles", 9, 186, 464, 103)
		GUICtrlSetFont(-1, 9.5, 800, 4, "Tahoma")
		$Marge = 30
		$Top = 17 + 186
		If FileExists($CheminSauve & "\" & $DossierSession) Then
			GUICtrlCreateLabel("Dossier de la session courante : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
			GUICtrlSetFont(-1, 9, 400) ;
			GUICtrlCreateInput($DossierSession, 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
			GUICtrlSetBkColor(-1, 0xFFFFFF)
		EndIf

		;======
		$aSize = DirGetSize("D:\Sauvegardes\BacBackup", 1)
		If Not @error Then

			$Top += $Marge
			$IntervalleInterSauvegardes = IniRead($CheminSauve & "\BacBackup.ini", "Params", "IntervalleInterSauvegardesEnMinutes", "")

			GUICtrlCreateLabel("Nombre de dossiers de session sauvegardés : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
			GUICtrlSetFont(-1, 9, 400) ;
			GUICtrlCreateInput(Round($aSize[2] / 2) & " dossiers", 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
			GUICtrlSetBkColor(-1, 0xFFFFFF)

			$Top += $Marge
			$IntervalleInterSauvegardes = IniRead($CheminSauve & "\BacBackup.ini", "Params", "IntervalleInterSauvegardesEnMinutes", "")

			GUICtrlCreateLabel("Taille totale du dossier de sauvegarde : ", 15, $Top, 285, 20, $SS_RIGHT, -1)
			GUICtrlSetFont(-1, 9, 400) ;
			GUICtrlCreateInput(_FineSize($aSize[0]), 306, $Top - 2, 158, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
			GUICtrlSetBkColor(-1, 0xFFFFFF)
		EndIf
	EndIf

	;Fin   *****************************************************************************************

	_AddControlsToPanel($aPanel[4])
	;Début *****************************************************************************************
	GUICtrlCreateIcon(@ScriptDir & "\res\Logo01-A-Propos-64x64.ico", -1, 6, 46, 128, 128)
	GUICtrlCreateIcon("./res/Txt-A-Propos-120x30.ico", -1, 10, 185, 120, 30)
	GUICtrlCreateLabel("BacBackup " & $Prog_Version, 200, 40, 250, 35, -1, -1)
	GUICtrlSetFont(-1, 18, 100, 0, "Tahoma")
;~ 	GUICtrlSetBkColor(-1, "-2")
	GUICtrlCreateLabel("Copyright © 2016-2022  La Communauté Tunisienne des Enseignants d'Informatique.", 200, 75, 280, 30, -1, -1)
	GUICtrlSetFont(-1, 8, 600, 0, "Comic Sans MS")
	GUICtrlSetBkColor(-1, "-2")

	$hGitHubURL = _GUICtrlHyperLink_Create("https://github.com/romoez/BacBackup", 200, 105, 280, 20, 0x0000FF, 0x551A8B, _
			 -1, '', "Téléchargement et code source")


	GUICtrlCreateLabel("BacBackup permet de: " & @CRLF & _
			"1. Surveiller et sauvegarder les dossiers de travail des élèves." & @CRLF & _
			"2. Prendre des captures d'écran toutes les 5 secondes.", 200, 135, 280, 75, -1, -1)
	GUICtrlSetFont(-1, 8, 400, 0, "Tahoma")
	GUICtrlSetBkColor(-1, "-2")
	GUICtrlCreateLabel("", 295, 198, 100, 2, $SS_SUNKEN) ;separator
	GUICtrlCreateLabel("Pour tout signalement d'erreur et pour toute suggestion d’amélioration, merci d'envoyer un e-mail à:", 200, 215, 280, 25, -1, -1)
	GUICtrlSetFont(-1, 8, 500, 0, "Tahoma")
	$hMail = _GUICtrlHyperLink_Create("moez.romdhane@tarbia.tn", 200, 245, -1, -1, 0x0000FF, 0x551A8B)
	;Fin   *****************************************************************************************
	;set default to Panel1
	GUISwitch($aPanel[1])
	;show the main GUI
	GUISetState(@SW_SHOW, $hMainGUI)
	;//Remplissage de la ListView
	RemplirListeView() ;
	While 1
		Sleep(10)
		$nMsg = GUIGetMsg(1)
		Switch $nMsg[1]
			Case $hMainGUI
				Switch $nMsg[0]
					Case $GUI_EVENT_CLOSE
						Exit
					Case $GUI_EVENT_MINIMIZE, $GUI_EVENT_MAXIMIZE, $GUI_EVENT_RESTORE
						$aPos = WinGetPos($hMainGUI)
						$iW = $aPos[2]
						$iH = $aPos[3]
						For $i = 0 To $aPanel[0]
							WinMove($aPanel[$i], "", $iLeftWidth + 2, $iT, $iW - $iLeftWidth + 2, $iH - $iT - $iB - 20)
						Next
					Case $aLink[3]
						ShellExecute(@ScriptDir & "\AideBB.chm")
					Case $aLink[1], $aLink[2], $aLink[4]
						For $i = 1 To $aLink[0]
							If $nMsg[0] = $aLink[$i] Then
								GUISetState(@SW_SHOW, $aPanel[$i])
							Else
								GUISetState(@SW_HIDE, $aPanel[$i])
							EndIf
						Next
					Case $GUI_Ouvrir_BasDePage
						If FileExists($CheminSauve & '\' & $DossierSession) Then
							Run("explorer.exe /e,/select, " & '"' & $CheminSauve & '\' & $DossierSession & '"')
							Sleep(1000)
							Exit
						ElseIf FileExists($CheminSauve) Then
							Run("explorer.exe /e, " & '"' & $CheminSauve & '"')
							Sleep(1000)
							Exit
						EndIf
					Case $LogoText, $Logo
						RemplirListeView()
				EndSwitch
			Case $aPanel[4] ;à propos
				Switch $nMsg[0]
					Case $hMail
						ShellExecute("mailto:moez.romdhane@tarbia.tn?subject=BacBackup " & $Prog_Version)
					Case $hGitHubURL
						ShellExecute("https://https://github.com/romoez/BacBackup", "", "", "open")  ;
				EndSwitch
		EndSwitch
	WEnd
EndFunc   ;==>_MainGui

;#########################################################################################

Func _AddNewLink($sTxt, $iIcon = -44)
	Local $hLink = GUICtrlCreateLabel($sTxt, 36, $iT + $iGap, $iLeftWidth - 46, 17)
	GUICtrlSetCursor(-1, 0)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	GUICtrlCreateIcon("shell32.dll", $iIcon, 10, $iT + $iGap, 16, 16)
	GUICtrlSetResizing(-1, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	$iGap += 22
	Return $hLink
EndFunc   ;==>_AddNewLink

;#########################################################################################

Func _AddNewPanel($sTxt)
	Local $gui = GUICreate("", $iW - $iLeftWidth + 2, $iH - $iT - $iB, $iLeftWidth + 2, $iT, $WS_CHILD + $WS_VISIBLE, -1, $hMainGUI)
	GUICtrlCreateLabel($sTxt, 10, 10, $iW - $iLeftWidth - 20, 17, $SS_CENTERIMAGE)
	GUICtrlSetFont(-1, 9, 800, 4, "Arial", 5)
	GUICtrlSetResizing(-1, $GUI_DOCKTOP + $GUI_DOCKLEFT + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	Return $gui
EndFunc   ;==>_AddNewPanel

;#########################################################################################

Func _AddControlsToPanel($hPanel)
	GUISwitch($hPanel)
EndFunc   ;==>_AddControlsToPanel

;#########################################################################################

Func RemplirListeView()
	_GUICtrlListView_DeleteAllItems($GUI_ListeFichiers)
	SplashTextOn("Sans Titre", "Préparation de la liste de dossiers surveillés." & @CRLF & @CRLF & "Veuillez patienter un moment..." & @CRLF, 330, 120, -1, -1, 49, "Segoe UI", 9)
	Local $Liste[1] = [0] ;
	Local $Kes ;
	;------
	$Kes = _DossiersTravailEleves() ;
	$Liste[0] += $Kes[0] ;
	_ArrayDelete($Kes, 0) ;
	_ArrayAdd($Liste, $Kes)
	;------
	$Kes = _DossiersSurBureau() ;
	$Liste[0] += $Kes[0] ;
	_ArrayDelete($Kes, 0) ;
	_ArrayAdd($Liste, $Kes)
	;------
	$Kes = DossiersTPW() ;
	$Liste[0] += $Kes[0] ;
	_ArrayDelete($Kes, 0) ;
	_ArrayAdd($Liste, $Kes)
	;------
	$Kes = DossiersEasyPHPwww() ;
	$Liste[0] += $Kes[0] ;
	_ArrayDelete($Kes, 0) ;
	_ArrayAdd($Liste, $Kes)
	;------
	$Kes = DossiersEasyPHPdata() ;
	$Liste[0] += $Kes[0] ;
	_ArrayDelete($Kes, 0) ;
	_ArrayAdd($Liste, $Kes)
	;------
	_ArraySort($Liste)

	Local $aItems[$Liste[0]][2]
	For $iI = 1 To $Liste[0]
		$aItems[$iI - 1][0] = $iI
		$aItems[$iI - 1][1] = $Liste[$iI]
	Next
	_GUICtrlListView_SetItemCount($GUI_ListeFichiers, UBound($aItems))
	_GUICtrlListView_AddArray($GUI_ListeFichiers, $aItems)
	$Liste = 0
	$aItems = 0
	SplashOff()
EndFunc   ;==>RemplirListeView

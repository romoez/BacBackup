#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup Auto-Sauvegarde)
#pragma compile(FileVersion, 2.3.0.501, 2.3.0.501)
#pragma compile(ProductName, BacBackup)
#pragma compile(ProductVersion, 2.3.0.501)

#pragma compile(LegalCopyright, 2016-2025 © La Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments,'BacBackup - Module de Surveillance')
#pragma compile(Out, Installer\Files\BacBackup.exe)
#pragma compile(CompanyName, La Communauté Tunisienne des Enseignants d'Informatique)

#include <ScreenCapture.au3>
#include <WinAPIFiles.au3>
#include <Utils.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <FileConstants.au3>
#include <String.au3>

;---------------------------------------------------Variables Globales-Début
Global $scrnsave ; Définie dans Initialisation()
Global $IntervalleInterSauvegardes ; Définie dans Initialisation()
Global $IntervalleInterCaptures
Global $TaillMaxDossierSessionEnGO = 5 ; GigaOctets
Global $DossierSession

; Variables pour la surveillance du presse-papier
Global $hClipboardGUI, $sLastClipboardText = ""
Global $sClipboardLogFile
Global Const $MAX_TEXT_SIZE = 100000 ; 100 Ko max pour le texte
Global Const $DEBOUNCE_TIME = 500 ; 500ms pour éviter les doublons rapides
Global $iLastClipboardTime = 0 ; Dernier traitement du presse-papier
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

OnAutoItExitRegister("_NettoyerRessources")
_KillOtherScript()
Initialisation()
InitialiserSurveillancePressePapier()
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
            _ProcessWindowsMessages()
        WEnd
        If $NombreTotalOperations >= 5000 Then
            If DirGetSize($DossierSession) / 1024 / 1024 / 1024 > $TaillMaxDossierSessionEnGO Then
                CleanUp()
                Initialisation()
                $NombreTotalOperations = 0
            EndIf
        EndIf
        LancerSauvegardeNormale()
        _ProcessWindowsMessages()
    WEnd
EndFunc   ;==>main

;#########################################################################################

Func Initialisation()
    $scrnsave = RegRead("HKEY_CURRENT_USER\Control Panel\Desktop", "SCRNSAVE.EXE")
    $scrnsave = StringRight($scrnsave, StringLen($scrnsave) - StringInStr($scrnsave, "\", 0, -1))

    $Lecteur = LecteurSauvegarde()
    $DossierSauvegardes = "Sauvegardes"
    If Not FileExists($Lecteur & $DossierSauvegardes) Then
        DirCreate($Lecteur & $DossierSauvegardes)
    EndIf
    FileSetAttrib($Lecteur & $DossierSauvegardes, "+SH")

    If Not FileExists($Lecteur & $DossierSauvegardes & "\BacBackup") Then
        _UnLockFolder($Lecteur & $DossierSauvegardes)
        DirCreate($Lecteur & $DossierSauvegardes & "\BacBackup")
    EndIf

    IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "DossierSauvegardes", $DossierSauvegardes)
    IniWrite($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "Lecteur", StringUpper($Lecteur))
    _LockFolder($Lecteur & $DossierSauvegardes)

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

    ; Créer le fichier journal
    $sClipboardLogFile = $DossierSession & "\journal_presse_papier.log"
    If Not FileExists($sClipboardLogFile) Then
        Local $hFile = FileOpen($sClipboardLogFile, $FO_OVERWRITE + $FO_UTF8_NOBOM)
        If $hFile <> -1 Then
            FileWrite($hFile, "Journal du Presse-papier" & @CRLF & _
                            "Session: " & $DossierSession & @CRLF & _
                            "Début: " & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & @CRLF & _
                            _StringRepeat("■", 80) & @CRLF & @CRLF)
            FileClose($hFile)
        EndIf
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

Func InitialiserSurveillancePressePapier()
    ; Créer une fenêtre cachée pour recevoir les messages du presse-papier
    $hClipboardGUI = GUICreate("ClipboardMonitor", 0, 0, 0, 0, 0, $WS_EX_TOOLWINDOW)
    GUISetState(@SW_HIDE, $hClipboardGUI)

    ; Enregistrer pour écouter les changements du presse-papier
    DllCall("user32.dll", "bool", "AddClipboardFormatListener", "hwnd", $hClipboardGUI)

    ; Enregistrer le message de mise à jour du presse-papier
    GUIRegisterMsg($WM_CLIPBOARDUPDATE, "OnClipboardChange")
EndFunc   ;==>InitialiserSurveillancePressePapier

;#########################################################################################

Func OnClipboardChange($hWnd, $Msg, $wParam, $lParam)
    If $hWnd <> $hClipboardGUI Then Return

    ; Debouncing : éviter les traitements trop rapides
    Local $iCurrentTime = TimerInit()
    If $iLastClipboardTime > 0 And TimerDiff($iLastClipboardTime) < $DEBOUNCE_TIME Then
        Return
    EndIf
    $iLastClipboardTime = $iCurrentTime

    ; Analyser le contenu du presse-papier
    _TraiterContenuPressePapier()
EndFunc   ;==>OnClipboardChange

;#########################################################################################

Func _TraiterContenuPressePapier()
    ; Vérifier d'abord si ce sont des fichiers (format CF_HDROP = 15)
    Local $bIsFile = False
    Local $hClipboard = DllCall("user32.dll", "bool", "OpenClipboard", "hwnd", 0)
    If $hClipboard[0] Then
        Local $hData = DllCall("user32.dll", "handle", "GetClipboardData", "uint", 15) ; CF_HDROP = 15
        If $hData[0] <> 0 Then
            $bIsFile = True
        EndIf
        DllCall("user32.dll", "bool", "CloseClipboard")
    EndIf

    ; Si ce sont des fichiers
    If $bIsFile Then
        Local $sText = ClipGet()
        If Not @error And $sText <> "" Then
            ; Optimisation : comparer d'abord les longueurs
            Local $iCurrentLen = StringLen($sText)
            Local $iLastLen = StringLen($sLastClipboardText)

            ; Si les longueurs diffèrent, c'est forcément différent
            If $iCurrentLen <> $iLastLen Or ($iCurrentLen = $iLastLen And $sText <> $sLastClipboardText) Then
                ; Les chemins de fichiers sont séparés par @CRLF ou des sauts de ligne
                Local $aFiles = StringSplit($sText, @CRLF, 0)
                Local $sFileList = ""
                Local $sTmpPath = "", $sAttrib = ""
                For $i = 1 To $aFiles[0]
                    $sTmpPath = StringStripWS($aFiles[$i], 3)
                    If $sTmpPath <> "" Then
                        $sAttrib = FileGetAttrib($sTmpPath)
                        If @error Or Not StringInStr($sAttrib, "D") Then
                            $sFileList &= "• " & $sTmpPath & @CRLF
                        Else
                            $sFileList &= "• " & _CreateDirTree($sTmpPath)
                        EndIf
                    EndIf
                Next
                If $sFileList <> "" Then
                    _EcrireJournalPressePapier("FICHIER(S)", $sFileList)
                    $sLastClipboardText = $sText
                EndIf
            EndIf
        EndIf
        Return
    EndIf

    ; Sinon, essayer de récupérer du texte (format CF_UNICODETEXT = 13)
    Local $sText = ClipGet()
    If Not @error And $sText <> "" Then
        ; Optimisation : comparer d'abord les longueurs
        Local $iCurrentLen = StringLen($sText)
        Local $iLastLen = StringLen($sLastClipboardText)

        ; Si les longueurs diffèrent, c'est forcément différent
        If $iCurrentLen <> $iLastLen Or ($iCurrentLen = $iLastLen And $sText <> $sLastClipboardText) Then
            Local $sTextToLog = $sText
            Local $bTruncated = False

            ; Tronquer si nécessaire
            If $iCurrentLen > $MAX_TEXT_SIZE Then
                $sTextToLog = StringLeft($sText, $MAX_TEXT_SIZE)
                $bTruncated = True
            EndIf

            ; Ajouter la remarque de troncature si nécessaire
            If $bTruncated Then
                $sTextToLog &= @CRLF & @CRLF & "*** TEXTE TRONQUÉ *** (Longueur originale : " & $iCurrentLen & " caractères, tronqué à " & $MAX_TEXT_SIZE & " caractères)"
            EndIf

            _EcrireJournalPressePapier("TEXTE", $sTextToLog)
            $sLastClipboardText = $sText ; On garde le texte complet pour la comparaison
        EndIf
    EndIf
EndFunc   ;==>_TraiterContenuPressePapier

;#########################################################################################

Func _EcrireJournalPressePapier($sType, $sContent)
    ; Rotation automatique si le fichier dépasse 10 Mo
    If FileExists($sClipboardLogFile) And FileGetSize($sClipboardLogFile) > 10 * 1024 * 1024 Then
        Local $sBackupName = StringReplace($sClipboardLogFile, ".log", "_" & @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & ".log")
        FileMove($sClipboardLogFile, $sBackupName, 1)
    EndIf

    Local $hFile = FileOpen($sClipboardLogFile, $FO_APPEND + $FO_UTF8_NOBOM)
    If $hFile = -1 Then
        $hFile = FileOpen($sClipboardLogFile, $FO_APPEND)
        If $hFile = -1 Then Return
    EndIf

    Local $sTimeStamp = @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & " " & _
                       StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC)

    FileWriteLine($hFile, "[" & $sTimeStamp & "] Type: " & $sType)
    FileWriteLine($hFile, $sContent)
    FileWriteLine($hFile, _StringRepeat("■", 80))
    FileClose($hFile)
EndFunc   ;==>_EcrireJournalPressePapier

;#########################################################################################

Func _ProcessWindowsMessages()
    ; Traiter les messages Windows pour la surveillance du presse-papier
    Local $msg = GUIGetMsg(1)
    If $msg[0] <> 0 Then
        ; Si c'est un message de fermeture de notre fenêtre cachée, on l'ignore
        If $msg[0] = $GUI_EVENT_CLOSE And $msg[1] = $hClipboardGUI Then
            ; Ne rien faire - garder la fenêtre ouverte
        EndIf
    EndIf
EndFunc   ;==>_ProcessWindowsMessages

;#########################################################################################

Func _NettoyerRessources()
    ; Désenregistrement propre du listener presse-papier
    If IsHWnd($hClipboardGUI) Then
        DllCall("user32.dll", "bool", "RemoveClipboardFormatListener", "hwnd", $hClipboardGUI)
        GUIDelete($hClipboardGUI)
    EndIf
EndFunc

;#########################################################################################
; Fonctions existantes de BacBackup (inchangées)
;#########################################################################################

Func Capturer($NbAppelRecursif = 0)
    Local $iIdleTime = _Timer_GetIdleTime()
    If $iIdleTime <= $IntervalleInterCaptures And Not ProcessExists($scrnsave) And WinGetTitle("") <> "" Then
        Local $NomImage = @HOUR & "h_" & @MIN & "_" & @SEC & ".png"
        _ScreenCapture_Capture($DossierSession & "\0-CapturesÉcran\" & $NomImage)

        If @error <> 0 Then
            If $NbAppelRecursif > 2 Then
                $IntervalleInterCaptures += $IntervalleInterCaptures
                Return
            EndIf
            Initialisation()
            $NbAppelRecursif += 1
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
    ShellExecute(@ScriptDir & "\BacBackup_Interface.exe", StringRegExpReplace($DossierSession, "(\\[^\\]*)$", ""))
EndFunc   ;==>AfficherInterface

;#########################################################################################

Func OuvrirDossierDeSauvegarde()
    $CheminSauve = IniRead(StringRegExpReplace($DossierSession, "(\\[^\\]*)$", "") & "\BacBackup.ini", "Params", "DossierSauvegardes", "")
    Run("explorer.exe /e, " & '"' & $CheminSauve & '"')
EndFunc   ;==>OuvrirDossierDeSauvegarde

;#########################################################################################

Func CleanUp()
    Local Const $NombreMaxDeDossiersDeSauve_Seuil_Minimum = 50
    Local Const $NombreMaxDeDossiersDeSauve_Default_Value = 750
    Local Const $NombreMaxDeDossiersDeSauve_Seuil_Maximum = 1000

    Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Minimum = 25 ; Go
    Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Default_Value = 200 ; Go
    Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Maximum = 500 ; Go

    Local $TailleMaxDuDossierBacBackupEnGigaoctet = IniRead(StringRegExpReplace($DossierSession, "(\\[^\\]*)$", "") & "\BacBackup.ini", "Params", "TailleMaxDuDossierBacBackupEnGigaoctet", "0")
    If StringIsInt($TailleMaxDuDossierBacBackupEnGigaoctet) = 0 Or $TailleMaxDuDossierBacBackupEnGigaoctet < $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Minimum Or $TailleMaxDuDossierBacBackupEnGigaoctet > $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Maximum Then
        $TailleMaxDuDossierBacBackupEnGigaoctet = $TailleMaxDuDossierBacBackupEnGigaoctet_Default_Value
        IniWrite(StringRegExpReplace($DossierSession, "(\\[^\\]*)$", "") & "\BacBackup.ini", "Params", "TailleMaxDuDossierBacBackupEnGigaoctet", $TailleMaxDuDossierBacBackupEnGigaoctet)
    EndIf

    $NombreMaxDeDossiersDeSauve = IniRead(StringRegExpReplace($DossierSession, "(\\[^\\]*)$", "") & "\BacBackup.ini", "Params", "NombreMaxDeDossiersDeSauve", "0")
    If StringIsInt($NombreMaxDeDossiersDeSauve) = 0 Or $NombreMaxDeDossiersDeSauve < $NombreMaxDeDossiersDeSauve_Seuil_Minimum Or $NombreMaxDeDossiersDeSauve > $NombreMaxDeDossiersDeSauve_Seuil_Maximum Then
        $NombreMaxDeDossiersDeSauve = $NombreMaxDeDossiersDeSauve_Default_Value
        IniWrite(StringRegExpReplace($DossierSession, "(\\[^\\]*)$", "") & "\BacBackup.ini", "Params", "NombreMaxDeDossiersDeSauve", $NombreMaxDeDossiersDeSauve)
    EndIf

    Local $aDrive = DriveGetDrive('FIXED')
    For $i = 1 To $aDrive[0]
        If (DriveGetType($aDrive[$i], $DT_BUSTYPE) <> "USB") And _WinAPI_IsWritable($aDrive[$i]) Then
            $Lecteur = $aDrive[$i]
            $Chemin = $Lecteur & "\Sauvegardes"
            If Not FileExists($Chemin & "\BacBackup") Then ContinueLoop

            If FileExists($Chemin & "\BacBackup\BacBackup.ini") Then
                Local $aDossiersEtNumeros = IniReadSection($Chemin & "\BacBackup\BacBackup.ini", "DerniersDossiers")
                If Not @error And IsArray($aDossiersEtNumeros) Then
                    Local $k = 1
                    While $k <= $aDossiersEtNumeros[0][0]
                        Local $KesDossier = $aDossiersEtNumeros[$k][0]
                        If Not FileExists($Chemin & "\Tmp\" & $KesDossier) Then
                            _ArrayDelete($aDossiersEtNumeros, $k)
                            $aDossiersEtNumeros[0][0] -= 1
                            ContinueLoop
                        EndIf
                        If Not FileExists($Chemin & "\Tmp\" & $KesDossier & "\dossier d'origine.lnk") Then
                            DirRemove($Chemin & "\Tmp\" & $KesDossier, 1)
                            _ArrayDelete($aDossiersEtNumeros, $k)
                            $aDossiersEtNumeros[0][0] -= 1
                            ContinueLoop
                        EndIf
                        Local $aDetails = FileGetShortcut($Chemin & "\Tmp\" & $KesDossier & "\dossier d'origine.lnk")
                        If @error Or Not FileExists($aDetails[0]) Then
                            DirRemove($Chemin & "\Tmp\" & $KesDossier, 1)
                            _ArrayDelete($aDossiersEtNumeros, $k)
                            $aDossiersEtNumeros[0][0] -= 1
                            ContinueLoop
                        EndIf
                        $aDossiersEtNumeros[$k][1] = "000"
                        $k += 1
                    WEnd
                    _ArraySort($aDossiersEtNumeros, 0, 1)
                    IniWriteSection($Chemin & "\BacBackup\BacBackup.ini", "DerniersDossiers", $aDossiersEtNumeros)
                EndIf
            EndIf

            Local $DossiersSessions = _FileListToArrayRec($Chemin & "\BacBackup", "*", 2, 0, 2, 2)
            If IsArray($DossiersSessions) And ($DossiersSessions[0] > $NombreMaxDeDossiersDeSauve / 10 _
                    Or Round(DirGetSize($Chemin & "\BacBackup\") / 1024 / 1024 / 1024) > $TailleMaxDuDossierBacBackupEnGigaoctet) Then
                For $j = Round($DossiersSessions[0] / 2) To 1 Step -1
                    DirRemove($DossiersSessions[$j], 1)
                Next
            EndIf
            _LockFolder($Chemin)
        EndIf
    Next
EndFunc   ;==>CleanUp

;#########################################################################################

Func _Timer_GetIdleTime()
    Local $tStruct = DllStructCreate("uint;dword")
    DllStructSetData($tStruct, 1, DllStructGetSize($tStruct))
    DllCall("user32.dll", "int", "GetLastInputInfo", "ptr", DllStructGetPtr($tStruct))

    Local $avTicks = DllCall("Kernel32.dll", "int", "GetTickCount")
    Local $iDiff = $avTicks[0] - DllStructGetData($tStruct, 2)
    If $iDiff >= 0 Then
        Return $iDiff
    Else
        Return SetError(0, 1, $avTicks[0])
    EndIf
EndFunc   ;==>_Timer_GetIdleTime
;#########################################################################################

Func _CreateDirTree($sDirectoryPath, $sFolderBar = "♦", $sTreeBar = "│", $sSeparator = "─", $iNSeparator = 3)

    Local $sFinalTree = ""
    Local $iMaxItems = 20
    Local $iItemCount = 0
;~     Local $aFiles = _FileListToArrayRec($sDirectoryPath, "*", $FLTAR_FILESFOLDERS, -2, $FLTAR_SORT)
	Local $aFiles = _FileListToArrayLimited($sDirectoryPath, $iMaxItems)

    ; ➤ 1. Afficher le **chemin complet** du dossier racine (sans indentation)
    $sFinalTree &= $sDirectoryPath & @CRLF

    ; ➤ 2. Parcourir les enfants, avec indentation globale de 4 espaces
    If IsArray($aFiles) And $aFiles[0] > 0 Then
;~ 		$sFinalTree &= "    ; recherche récursive limitée à 2 niveaux de profondeur" & @CRLF
		$sFinalTree &= "    ; affichage limité aux " & $iMaxItems & " premiers éléments trouvés" & @CRLF
        For $i = 1 To $aFiles[0]
            $iItemCount += 1

            Local $sRelativePath = $aFiles[$i]
            Local $sFilePath = $sDirectoryPath & "\" & $sRelativePath
            Local $sAttrib = FileGetAttrib($sFilePath)

            Local $sName = StringInStr($sAttrib, "D") ? _GetFolderName($sFilePath) : _GetFileName($sFilePath)
            Local $sIndentation = _GenerateIndentNodes($sDirectoryPath, $sRelativePath, $sFolderBar, $sTreeBar, $sSeparator)

            ; ➤ Ajout des 4 espaces d'indentation globale pour les enfants
            $sFinalTree &= "    " & $sIndentation & $sName & @CRLF
        Next

        ; ➤ 3. Message de troncature (aussi indenté de 4 espaces)
        If $aFiles[0] = $iMaxItems Then
;~             $sFinalTree &= @CRLF & "    … [+ " & ($aFiles[0] - $iMaxItems) & " élément" & (($aFiles[0] - $iMaxItems) = 1 ? "" : "s") & " omis]" & @CRLF
            $sFinalTree &= "    … [résultat tronqué]" & @CRLF & @CRLF
        EndIf
    EndIf

    Return $sFinalTree
EndFunc   ;==>_CreateDirTree


Func _CountItemsInFolder($sDirectoryPath)
    Local $hSearch = FileFindFirstFile($sDirectoryPath & "\*.*")
    If $hSearch = -1 Then Return 0

    Local $iCount = 0
    While 1
        FileFindNextFile($hSearch)
        If @error Then ExitLoop
        $iCount += 1
    WEnd
    FileClose($hSearch)
    Return $iCount
EndFunc


Func _GenerateIndentNodes($sDirectoryPath, $sFolderRelativePath, $sFolderBar, $sTreeBar, $sSeparator, $iNSeparator = 3)
    Local $aSplit = StringSplit($sFolderRelativePath, "\")
    Local $iDepth = $aSplit[0]

    ; ➤ Cas élément direct (1er niveau) : "♦───"
    If $iDepth = 1 Then
        Return $sFolderBar & _StringRepeat($sSeparator, $iNSeparator)
    EndIf

    ; ➤ Cas général (profondeur ≥ 2)
    Local $sBars = ""
    Local $sFilePath = ""

    For $i = 1 To $iDepth - 1
        $sFilePath = _ArrayToString($aSplit, "\", 1, $i)
        Local $iFiles = _CountItemsInFolder($sDirectoryPath & "\" & $sFilePath)

        If $i = $iDepth - 1 Then
            $sBars &= $sFolderBar & _StringRepeat($sSeparator, $iNSeparator)
        Else
            $sBars &= ($iFiles > 1) ? $sTreeBar & _StringRepeat(" ", $iNSeparator) : " " & _StringRepeat(" ", $iNSeparator)
        EndIf
    Next

    Return $sBars
EndFunc   ;==>_GenerateIndentNodes


Func _GetFileName($sFullPath)
    Local $aSplit = StringSplit($sFullPath, "\")
    Return $aSplit[$aSplit[0]]
EndFunc


Func _GetFolderName($sFullPath)
    Local $aSplit = StringSplit($sFullPath, "\")
    Return $aSplit[$aSplit[0]]
EndFunc

;==================================================================================
; _FileListToArrayLimited($sRootDir, $iMaxItems = 20)
; Parcourt récursivement en profondeur, mais s'arrête dès que $iMaxItems sont trouvés.
; Retourne tableau 1D : [0]=nb, [1..n]=chemins relatifs
;==================================================================================
Func _FileListToArrayLimited($sRootDir, $iMaxItems = 20)
    Local $aResult[1] = [0]
    Local $iCount = 0

    ; Fonction récursive interne (utilise ByRef pour $iCount et $aResult)
    _TraverseDir($sRootDir, "", $sRootDir, $iCount, $aResult, $iMaxItems)

    $aResult[0] = $iCount
    Return $aResult
EndFunc


; Fonction récursive interne — ne pas appeler directement
Func _TraverseDir($sBaseDir, $sRelPath, $sCurrentDir, ByRef $iCount, ByRef $aResult, $iMax)
    If $iCount >= $iMax Then Return ; ✅ arrêt immédiat

    Local $hSearch = FileFindFirstFile($sCurrentDir & "\*.*")
    If $hSearch = -1 Then Return

    Local $aFilesSorted[0] ; pour trier localement (facultatif mais recommandé)

    ; 1. Lister tous les éléments du dossier courant (sans les traiter encore)
    While 1
        Local $sName = FileFindNextFile($hSearch)
        If @error Then ExitLoop
        _ArrayAdd($aFilesSorted, $sName)
    WEnd
    FileClose($hSearch)

    ; 2. Trier (pour cohérence avec _FileListToArrayRec + $FLTAR_SORT)
    _ArraySort($aFilesSorted)

    ; 3. Parcourir dans l'ordre trié
    For $i = 0 To UBound($aFilesSorted) - 1
        If $iCount >= $iMax Then ExitLoop

        Local $sName = $aFilesSorted[$i]
        Local $sFullPath = $sCurrentDir & "\" & $sName
        Local $sNewRelPath = ($sRelPath = "") ? $sName : $sRelPath & "\" & $sName

        ; ➤ Ajouter l'élément (fichier ou dossier)
        _ArrayAdd($aResult, $sNewRelPath)
        $iCount += 1

        ; ➤ Si c'est un dossier → descendre dedans (récursion)
        If StringInStr(FileGetAttrib($sFullPath), "D") Then
            _TraverseDir($sBaseDir, $sNewRelPath, $sFullPath, $iCount, $aResult, $iMax)
        EndIf
    Next
EndFunc
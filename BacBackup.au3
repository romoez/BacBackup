;~ #NoTrayIcon
#Region ;**** Directives AutoIt3Wrapper ****
#AutoIt3Wrapper_Run_Au3Stripper=y
;~ #Au3Stripper_Parameters=/rm /mo /sf /sv
#Au3Stripper_Parameters=/rm /sf /sv
#AutoIt3Wrapper_UseUpx=n
#EndRegion

#Region ;**** Métadonnées de l'application ****
#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup - Service de surveillance)
#pragma compile(FileVersion, 2.5.26.218)
#pragma compile(ProductVersion, 2.5.26.218)
#pragma compile(ProductName, BacBackup)
#pragma compile(InternalName, BacBackup)
#pragma compile(OriginalFilename, BacBackup.exe)
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
#pragma compile(Out, Installer\Files\BacBackup.exe)
#EndRegion

#include <ScreenCapture.au3>
#include <WinAPIFiles.au3>
#include <Utils.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <FileConstants.au3>
#include <String.au3>
#include <Misc.au3>
#include <TrayConstants.au3>

;---------------------------------------------------Variables Globales-Début
Global $scrnsave ; Définie dans Initialisation()
Global $IntervalleInterSauvegardes ; Définie dans Initialisation()
Global $IntervalleInterCaptures
Global $TaillMaxDossierSessionEnGO = 1 ; GigaOctets
Global Const $MAX_CAPTURES_ECRAN = 1000
Global Const $INACTIVITY_THRESHOLD_MS = 30 * 60 * 1000  ; 30 minutes
Global $DossierSession

; Variables pour la surveillance du presse-papier
Global $hClipboardGUI, $sLastClipboardText = ""
Global $sClipboardLogFile
Global Const $MAX_TEXT_SIZE = 100000 ; 100 Ko max pour le texte
Global Const $DEBOUNCE_TIME = 500 ; 500ms pour éviter les doublons rapides
Global $iLastClipboardTime = 0 ; Dernier traitement du presse-papier

; ******************************************************************
Global $g_iLastCaptureTime = 0 ; Temps de la dernière capture réussie
Global $g_iTotalCaptures = 0 ; Nombre total de captures dans cette session
Global $Lecteur
Global Const $DossierSauvegardes = "Sauvegardes"

; ******************************************************************
Global $g_LastInputTick = 0 ; pour détection veille
; Initialiser le tick de dernière activité
Global $tLastInput = DllStructCreate("dword;dword")
DllCall("user32.dll", "bool", "GetLastInputInfo", "ptr", DllStructGetPtr($tLastInput))
$g_LastInputTick = DllStructGetData($tLastInput, 2)
Global $g_bPendingNewSessionAfterIdle = False
Global $g_LongIdleDuration = 0 ; variable pour stocker la durée de l'inactivité

; Variables pour la surveillance USB
Global Const $DBT_DEVICEARRIVAL = 0x00008000
Global Const $DBT_DEVICECOMPLETEREMOVAL = 0x00008004
;~ Global Const $WM_DEVICECHANGE = 0x0219
Global $g_aDrives

;~ Forcer le mode "DPI Aware" pour capturer la totalité de l'écran
DllCall("user32.dll", "bool", "SetProcessDPIAware")

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
CleanUp()
InitialiserSurveillancePressePapier()
Opt("TrayOnEventMode", 1) ; Active le mode événement pour l'icône (ne bloque pas le script)
Opt("TrayMenuMode", 1)    ; Désactive le menu par défaut (Pause/Exit) au clic droit
TraySetToolTip("BacBackup - Surveillance active") ; Texte au survol de la souris
; Associe le double-clic gauche à la fonction de gestion
TraySetOnEvent($TRAY_EVENT_PRIMARYDOUBLE, "_GestionDoubleClicTray")
main()

;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@     Fin Programme Principal    @@@@@@@@@@@@@@@@@@@@@@@
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Func main()
    Local $NbCapturesReelles = 0
    Local $NombreTotalOperations = 0
    Local $tStartCycle = 0
    Local $bLongIdleTriggered = False

    While 1
        ; Boucle de surveillance (2 min par cycle)
        $tStartCycle = TimerInit()
        $NbCapturesReelles = 0
		$scrnsave = _GetScreensaverName()

        While TimerDiff($tStartCycle) < $IntervalleInterSauvegardes
            Sleep($IntervalleInterCaptures)

            ; Capturer() retourne 1/0 → on compte seulement les vraies captures
            Local $iCaptureResult = Capturer()
            $NbCapturesReelles += $iCaptureResult
            $NombreTotalOperations += 1

            ; Mettre à jour le temps de dernière capture si capture réussie
            If $iCaptureResult = 1 Then
                $g_iLastCaptureTime = TimerInit()
                $bLongIdleTriggered = False ; Réinitialiser le flag si activité détectée
            EndIf

			If Mod($NombreTotalOperations, 4) = 0 Then ; Vérifier toutes les 4 itérations (~20s)
				Local $sIniSessionName = IniRead($Lecteur & $DossierSauvegardes & "\BacBackup\BacBackup.ini", "Params", "DossierSession", "")
				If StringInStr($sIniSessionName, "BacCollector") Then
					CleanUp()
					Initialisation("Nouvelle session initiée par BacCollector")
					$g_iTotalCaptures = 0
					$NombreTotalOperations = 0
					$bLongIdleTriggered = False
                    $sLastClipboardText = ""
					$g_bPendingNewSessionAfterIdle = False
                    ContinueLoop 2
				EndIf
			EndIf
            _ProcessWindowsMessages()
        WEnd

		; Cas 1 : trop de captures + dossier trop gros → nouvelle session
        If $g_iTotalCaptures >= $MAX_CAPTURES_ECRAN Then
            Local $tailleGO = DirGetSize($DossierSession) / 1024 / 1024 / 1024
            If $tailleGO > $TaillMaxDossierSessionEnGO Then
                CleanUp()
                Initialisation("Limite atteinte : " & $g_iTotalCaptures & " captures, taille = " & Round($tailleGO, 2) & " Go")
                $g_iTotalCaptures = 0
                $NombreTotalOperations = 0
                $bLongIdleTriggered = False
				$g_bPendingNewSessionAfterIdle = False
                ContinueLoop
            EndIf
        EndIf

        ; Cas 2 : activité après long idle (>30 min) → marquer pour nouvelle session (à créer au moment de la reprise d'activité - dans Capturer())
        Local $iIdleTime = _Timer_GetIdleTime()
        If $iIdleTime > $INACTIVITY_THRESHOLD_MS Then
            If Not $bLongIdleTriggered Then
                $g_bPendingNewSessionAfterIdle = True
                $bLongIdleTriggered = True
            EndIf
			$g_LongIdleDuration = $iIdleTime
        Else
            ; Réinitialiser le flag si l'utilisateur est actif
            $bLongIdleTriggered = False
        EndIf

        ; Lancer la sauvegarde normale seulement si des captures ont été faites
        If $NbCapturesReelles > 0 Then
            LancerSauvegardeNormale()
        EndIf

        _ProcessWindowsMessages()
    WEnd
EndFunc

;#########################################################################################

;#########################################################################################

Func Initialisation($Cause = "")

    $Lecteur = LecteurSauvegarde()
    ; Variables locales pour les chemins répétitifs
    Local $sDossierBase = StringUpper($Lecteur) & $DossierSauvegardes
    Local $sDossierBacBackup = $sDossierBase & "\BacBackup"
    Local $sDossierBacCollector = $sDossierBase & "\BacCollector"
    Local $sDossierTmp = $sDossierBase & "\Tmp"

    Local $sIniPath = $sDossierBacBackup & "\BacBackup.ini"
    ; Créer dossier de base
    If Not FileExists($sDossierBase) Then
        DirCreate($sDossierBase)
    EndIf

    ; Créer dossier BacBackup
    If Not FileExists($sDossierBacBackup) Then
		_UnlockFolder($sDossierBase)
        DirCreate($sDossierBacBackup)
    EndIf
	_LockFolderContents($sDossierBacBackup)

    ; Créer dossier BacBackup
    If Not FileExists($sDossierBacCollector) Then
		_UnlockFolder($sDossierBase)
        DirCreate($sDossierBacCollector)
    EndIf
	_LockFolderContents($sDossierBacCollector)

    ; Créer dossier Tmp (utilisé par le module de Sauvegarde)
    If Not FileExists($sDossierTmp) Then
		_UnlockFolder($sDossierBase)
        DirCreate($sDossierTmp)
    EndIf

	; Vérrouiller le dossier C:\Sauvegarde après création des sous-dossiers
	_LockRootFolder($sDossierBase)

    ; Écrire paramètres de base
    IniWrite($sIniPath, "Params", "DossierSauvegardes", $DossierSauvegardes)
    IniWrite($sIniPath, "Params", "Lecteur", StringUpper($Lecteur))

    ; ═══════════════════════════════════════════════════════════════════
    ; GÉNÉRATION DU NUMÉRO DE SESSION INCRÉMENTÉ
    ; ═══════════════════════════════════════════════════════════════════
    Local $sOldSessionName = IniRead($sIniPath, "Params", "DossierSession", "")

    Local $Tmp = StringLeft($sOldSessionName, 3)
    If StringRegExp($Tmp, "^[0-9]{3}$", 0) = 0 Then
        $Tmp = 1
    Else
        $Tmp = Int($Tmp) + 1
        If $Tmp > 999 Then
            $Tmp = 1
        EndIf
    EndIf

    Local $sNumeroSession = StringFormat("%03d", $Tmp)

    Local $sNomSession = $sNumeroSession & '___' & _
                         StringFormat("%02d", @MDAY) & "_" & _
                         StringFormat("%02d", @MON) & "_" & _
                         @YEAR & "___" & _
                         StringFormat("%02d", @HOUR) & "h" & _
                         StringFormat("%02d", @MIN)

    ; Écrire le nouveau nom de session dans le INI
    IniWrite($sIniPath, "Params", "DossierSession", $sNomSession)

    ; Mettre à jour la variable GLOBALE
    $DossierSession = $sDossierBase & "\BacBackup\" & $sNomSession

    ; Créer les dossiers de session
    If Not FileExists($DossierSession) Then
        DirCreate($DossierSession)
    EndIf

    Local $sCaptureDir = $DossierSession & "\_CapturesEcran"
    If Not FileExists($sCaptureDir) Then
        DirCreate($sCaptureDir)
    EndIf

    ; ═══════════════════════════════════════════════════════════════════
    ; CRÉATION DU FICHIER D'INFORMATION DE SESSION
    ; ═══════════════════════════════════════════════════════════════════
    Local $sTexteDeclencheur = ($Cause = "") ? "Démarrage de BacBackup" : $Cause
    Local $sInfoFile = $DossierSession & "\_info_session.txt"
    Local $hInfo = FileOpen($sInfoFile, $FO_OVERWRITE + $FO_UTF8_NOBOM)
    If $hInfo <> -1 Then
        FileWrite($hInfo, _
            "═══════════════════════════════════════════════════════" & @CRLF & _
            "  INFORMATIONS DE SESSION - BacBackup" & @CRLF & _
            "═══════════════════════════════════════════════════════" & @CRLF & @CRLF & _
            "Déclencheur  : " & $sTexteDeclencheur & @CRLF & _
            "Date/Heure   : " & @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
            " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC) & @CRLF & _
            "Session      : " & $sNomSession & @CRLF & _
            "Ordinateur   : " & @ComputerName & @CRLF & _
            "Utilisateur  : " & @UserName & @CRLF & _
            "Système      : " & @OSVersion & " (" & @OSArch & ")" & @CRLF)
        FileClose($hInfo)
    EndIf

    ; Mettre à jour la variable GLOBALE
    $sClipboardLogFile = $DossierSession & "\_journal_presse_papier.log"

    ; Créer le fichier journal du presse-papier
    If Not FileExists($sClipboardLogFile) Then
        Local $hFile = FileOpen($sClipboardLogFile, $FO_OVERWRITE + $FO_UTF8_NOBOM)
        If $hFile <> -1 Then
            FileWrite($hFile, _StringRepeat("═", 80) & @CRLF & _
                    "  JOURNAL DU PRESSE-PAPIER" & @CRLF & _
                    _StringRepeat("═", 80) & @CRLF & @CRLF & _
                    "Session : " & $DossierSession & @CRLF & _
                    "Début   : " & @YEAR & "-" & StringFormat("%02d", @MON) & "-" & StringFormat("%02d", @MDAY) & _
                    " " & StringFormat("%02d", @HOUR) & ":" & StringFormat("%02d", @MIN) & ":" & StringFormat("%02d", @SEC) & @CRLF & _
                    _StringRepeat("■", 80) & @CRLF)
            FileClose($hFile)
        EndIf
    EndIf

    ; ═══════════════════════════════════════════════════════════════════
    ; LECTURE DES PARAMÈTRES DE CONFIGURATION
    ; ═══════════════════════════════════════════════════════════════════
    $IntervalleInterSauvegardes = IniRead($sIniPath, "Params", "IntervalleInterSauvegardesEnMinutes", "2")
    If Not StringIsInt($IntervalleInterSauvegardes) Or $IntervalleInterSauvegardes < 1 Or $IntervalleInterSauvegardes > 15 Then
        $IntervalleInterSauvegardes = 2
        IniWrite($sIniPath, "Params", "IntervalleInterSauvegardesEnMinutes", $IntervalleInterSauvegardes)
    EndIf
    $IntervalleInterSauvegardes *= 60000

    $IntervalleInterCaptures = IniRead($sIniPath, "Params", "IntervalleInterCapturesEnSecondes", "5")
    If Not StringIsInt($IntervalleInterCaptures) Or $IntervalleInterCaptures < 2 Or $IntervalleInterCaptures > 20 Then
        $IntervalleInterCaptures = 5
        IniWrite($sIniPath, "Params", "IntervalleInterCapturesEnSecondes", $IntervalleInterCaptures)
    EndIf
    $IntervalleInterCaptures *= 1000
EndFunc   ;==>Initialisation

;#########################################################################################
Func Capturer()

    ; Vérifier si le système sort d'une veille/suspend
    DllCall("user32.dll", "bool", "GetLastInputInfo", "ptr", DllStructGetPtr($tLastInput))
    Local $currentTick = DllStructGetData($tLastInput, 2)

    ; Gestion du débordement du tick (49.7 jours)
    If $currentTick < $g_LastInputTick Then
        $g_LastInputTick = $currentTick
        Return 0
    EndIf

    Local $tickDiff = $currentTick - $g_LastInputTick

    ; Si le tick a sauté (veille/suspend) > 30 minutes
    If $tickDiff > $INACTIVITY_THRESHOLD_MS Then ; 30 min = 1 800 000 ms

        CleanUp()
        Initialisation("Sortie de veille/suspend (" & Round($tickDiff / 60000, 0) & " min d'inactivité)")

        $g_LastInputTick = $currentTick
        $g_iTotalCaptures = 0
        $sLastClipboardText = ""
		$g_bPendingNewSessionAfterIdle = False
		$g_LongIdleDuration = 0
        Return 0
    EndIf
    $g_LastInputTick = $currentTick

    ; Temps d'inactivité en ms
    Local $iIdleTime = _Timer_GetIdleTime()

	; Vérifier si une nouvelle session est en attente
    If $g_bPendingNewSessionAfterIdle Then
        ; Vérifier qu'il y a VRAIMENT une activité maintenant
        If $iIdleTime <= $IntervalleInterCaptures Then
            ; Activité détectée ! Créer la nouvelle session
            CleanUp()
			Initialisation("Reprise après inactivité prolongée (" & Round($g_LongIdleDuration / 60000, 0) & " min)")
            $g_iTotalCaptures = 0
            $sLastClipboardText = ""
            $g_bPendingNewSessionAfterIdle = False
			$g_LongIdleDuration = 0
            ; Ne pas capturer cette fois-ci, laisser la prochaine itération le faire
            Return 0
        EndIf
    EndIf

    ; Conditions pour capturer :
    ; - Pas d'économiseur d'écran actif
    ; - Temps d'inactivité < seuil (ex: < 5s pour éviter captures inutiles)
    ; - Une fenêtre active existe
    Local $bScreensaverActive = False
    If $scrnsave <> "" Then  ; Seulement si un économiseur est configuré
        $bScreensaverActive = ProcessExists($scrnsave)
    EndIf

    If $iIdleTime <= $IntervalleInterCaptures And _
       Not $bScreensaverActive And _
       WinGetTitle("") <> "" Then
        Local $sCaptureDir = $DossierSession & "\_CapturesEcran"

        If Not FileExists($sCaptureDir) Then
            ; Si échec de création, abandonner
            If Not DirCreate($sCaptureDir) Then
                Return 0
            EndIf
        EndIf

        ; Générer un nom de fichier avec numéro séquentiel
        $g_iTotalCaptures += 1

        ; Générer un nom de fichier avec numéro séquentiel
        Local $NomImage = StringFormat("%04d", $g_iTotalCaptures) & "_" & _
                          StringFormat("%02d", @HOUR) & "h" & _
                          StringFormat("%02d", @MIN) & "_" & _
                          StringFormat("%02d", @SEC) & ".png"
        Local $sPath = $sCaptureDir & "\" & $NomImage

        _ScreenCapture_Capture($sPath)

        If @error = 0 And FileExists($sPath) Then
            ; Vérifier si le fichier n'est pas vide/corrompu
            ; Une capture d'écran PNG fait plus de 10 KB
            If FileGetSize($sPath) > 10240 Then ; > 10 KB
                Return 1 ; Capture réussie
            Else
                ; Fichier anormalement petit = probablement corrompu
                FileDelete($sPath)
                $g_iTotalCaptures -= 1
                Return 0
            EndIf
        Else
            ; Annuler l'incrémentation si erreur - Pas de capture
            $g_iTotalCaptures -= 1
            Return 0
        EndIf
    EndIf
EndFunc   ;==>Capturer

;~ ###############################################################################
Func LancerSauvegardeNormale()
	Capturer()
	Local $iIdleTime = _Timer_GetIdleTime()
    Local $bScreensaverActive = False
    If $scrnsave <> "" Then
        $bScreensaverActive = ProcessExists($scrnsave)
    EndIf
    If $iIdleTime <= $IntervalleInterSauvegardes And _
       Not $bScreensaverActive And _
       WinGetTitle("") <> "" Then
		ShellExecute(@ScriptDir & "\BacBackup_Sauvegarder.exe", 'normale' & " " & $DossierSession)
	EndIf
EndFunc   ;==>LancerSauvegardeNormale

;#########################################################################################
Func LancerSauvegardeForcee()
	Capturer()
	ShellExecute(@ScriptDir & "\BacBackup_Sauvegarder.exe", 'forcee' & " " & $DossierSession)
EndFunc   ;==>LancerSauvegardeForcee

;#########################################################################################

Func _GetScreensaverName()
    ; Lecture directe du registre sans cache
    Local $sReg = RegRead("HKEY_CURRENT_USER\Control Panel\Desktop", "SCRNSAVE.EXE")

    If @error Then
        ; Si erreur de lecture (clé inexistante, droits insuffisants)
        Return "scrnsave.scr"  ; Valeur par défaut sécurisée
    EndIf

    If $sReg = "" Then
        ; Économiseur désactivé (chaîne vide dans le registre)
        Return ""  ; Chaîne vide indique aucun économiseur
    EndIf

    ; Extraire juste le nom du fichier (sans le chemin)
    Local $iLastBackslash = StringInStr($sReg, "\", 0, -1)  ; Dernière occurrence de "\"

    If $iLastBackslash > 0 Then
        Return StringMid($sReg, $iLastBackslash + 1)  ; Partie après le dernier "\"
    Else
        Return $sReg  ; Déjà juste le nom
    EndIf
EndFunc   ;==>_GetScreensaverName

;#########################################################################################

Func InitialiserSurveillancePressePapier()
	; Créer une fenêtre cachée pour recevoir les messages du presse-papier ET USB
	$hClipboardGUI = GUICreate("BacBackupMonitor", 0, 0, 0, 0, 0, $WS_EX_TOOLWINDOW)
	GUISetState(@SW_HIDE, $hClipboardGUI)

	; Enregistrer pour écouter les changements du presse-papier
	DllCall("user32.dll", "bool", "AddClipboardFormatListener", "hwnd", $hClipboardGUI)

	; Enregistrer les messages
	GUIRegisterMsg($WM_CLIPBOARDUPDATE, "OnClipboardChange")
	GUIRegisterMsg($WM_DEVICECHANGE, "OnDeviceChange") ; ★ AJOUT surveillance USB

	; Initialiser la liste des lecteurs
	_UpdateDrives()
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
	Local $bIsFile = False
	Local $hClipboard = DllCall("user32.dll", "bool", "OpenClipboard", "hwnd", 0)
	If $hClipboard[0] Then
		Local $hData = DllCall("user32.dll", "handle", "GetClipboardData", "uint", 15)
		If $hData[0] <> 0 Then $bIsFile = True
		DllCall("user32.dll", "bool", "CloseClipboard")
	EndIf

	If $bIsFile Then
		Local $sText = ClipGet()
		If Not @error And $sText <> "" Then
			Local $iCurrentLen = StringLen($sText)
			Local $iLastLen = StringLen($sLastClipboardText)

			If $iCurrentLen <> $iLastLen Or ($iCurrentLen = $iLastLen And $sText <> $sLastClipboardText) Then
				Local $aFiles = StringSplit($sText, @CRLF, 0)
				Local $sFileList = ""
				For $i = 1 To $aFiles[0]
					Local $sPath = StringStripWS($aFiles[$i], 3)
					If $sPath = "" Then ContinueLoop

					Local $sAttrib = FileGetAttrib($sPath)
					If @error Then
						$sFileList &= "- " & $sPath & @CRLF
					ElseIf StringInStr($sAttrib, "D") Then
						; ➤ Dossier : "+ chemin" puis arborescence indentée de 2 espaces
						$sFileList &= "+ " & $sPath & @CRLF
						Local $sTree = _DirTreeToString($sPath, 20)
						If $sTree <> "" Then
							Local $aLines = StringSplit(StringStripWS($sTree, 2), @CRLF, 2)
							For $j = 0 To UBound($aLines) - 1
								If $aLines[$j] <> "" Then
									$sFileList &= "  " & $aLines[$j] & @CRLF
								EndIf
							Next
						EndIf
					Else
						; ➤ Fichier
						$sFileList &= "- " & $sPath & @CRLF
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

	; Gestion du texte
	Local $sText = ClipGet()
	If Not @error And $sText <> "" Then
		Local $iCurrentLen = StringLen($sText)
		Local $iLastLen = StringLen($sLastClipboardText)

		If $iCurrentLen <> $iLastLen Or ($iCurrentLen = $iLastLen And $sText <> $sLastClipboardText) Then
			Local $sTextToLog = $sText
			Local $bTruncated = False
			If $iCurrentLen > $MAX_TEXT_SIZE Then
				$sTextToLog = StringLeft($sText, $MAX_TEXT_SIZE)
				$bTruncated = True
			EndIf
			If $bTruncated Then
				$sTextToLog &= @CRLF & @CRLF & "*** TEXTE TRONQUÉ *** (Longueur originale : " & $iCurrentLen & " caractères, tronqué à " & $MAX_TEXT_SIZE & " caractères)"
			EndIf
			_EcrireJournalPressePapier("TEXTE", $sTextToLog)
			$sLastClipboardText = $sText
		EndIf
	EndIf
EndFunc

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
	Local $Msg = GUIGetMsg(1)
	If $Msg[0] <> 0 Then
		; Si c'est un message de fermeture de notre fenêtre cachée, on l'ignore
		If $Msg[0] = $GUI_EVENT_CLOSE And $Msg[1] = $hClipboardGUI Then
			; Ne rien faire - garder la fenêtre ouverte
		EndIf
	EndIf
EndFunc   ;==>_ProcessWindowsMessages

;#########################################################################################

Func _NettoyerRessources()
	; Désenregistrement du listener presse-papier
	If IsHWnd($hClipboardGUI) Then
		DllCall("user32.dll", "bool", "RemoveClipboardFormatListener", "hwnd", $hClipboardGUI)
		GUIDelete($hClipboardGUI)
		$hClipboardGUI = 0 ; Réinitialiser pour éviter les fuites
	EndIf
EndFunc   ;==>_NettoyerRessources

;#########################################################################################

Func AfficherInterface()
	ShellExecute(@ScriptDir & "\BacBackup_Interface.exe", StringRegExpReplace($DossierSession, "(\\[^\\]*)$", ""))
	LancerSauvegardeNormale()
EndFunc   ;==>AfficherInterface

;#########################################################################################

Func OuvrirDossierDeSauvegarde()
	$CheminSauve = IniRead(StringRegExpReplace($DossierSession, "(\\[^\\]*)$", "") & "\BacBackup.ini", "Params", "DossierSauvegardes", "")
	Run("explorer.exe /e, " & '"' & $CheminSauve & '"')
EndFunc   ;==>OuvrirDossierDeSauvegarde

;#########################################################################################

Func CleanUp()
	Local Const $NombreMaxDeDossiersDeSauve_Seuil_Minimum = 20
	Local Const $NombreMaxDeDossiersDeSauve_Default_Value = 100
	Local Const $NombreMaxDeDossiersDeSauve_Seuil_Maximum = 500

	Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Minimum = 10 ; Go
	Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Default_Value = 50 ; Go
	Local Const $TailleMaxDuDossierBacBackupEnGigaoctet_Seuil_Maximum = 200 ; Go

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
	Local $sDrive
	Local $aDrives = DriveGetDrive('FIXED')
	For $i = 1 To $aDrives[0]
		If (DriveGetType($aDrives[$i], $DT_BUSTYPE) <> "USB") And _WinAPI_IsWritable($aDrives[$i]) Then
			$sDrive = $aDrives[$i]
			$Chemin = $sDrive & "\Sauvegardes"
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
			If IsArray($DossiersSessions) And ($DossiersSessions[0] > $NombreMaxDeDossiersDeSauve _
					Or Round(DirGetSize($Chemin & "\BacBackup\") / 1024 / 1024 / 1024) > $TailleMaxDuDossierBacBackupEnGigaoctet) Then
				_UnlockFolder($Chemin & "\BacBackup")
				For $j = Round($DossiersSessions[0] / 2) To 1 Step -1
					DirRemove($DossiersSessions[$j], 1)
				Next
				_LockFolderContents($Chemin & "\BacBackup")
			EndIf
		EndIf
	Next
EndFunc   ;==>CleanUp

;#########################################################################################
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

;#########################################################################################

Func OnDeviceChange($hWnd, $Msg, $wParam, $lParam)
;~ 	MsgBox(0, "", "Entrée dans la fonction DeviceChange") ; Décommenter pour debug
	If $hWnd <> $hClipboardGUI Then Return
	Switch $wParam
		Case $DBT_DEVICECOMPLETEREMOVAL
			_UpdateDrives()
		Case $DBT_DEVICEARRIVAL
			Local $sNewDrive = _FindNewDrive()
			If $sNewDrive <> "" And DriveStatus($sNewDrive) = "READY" Then
				; Recherche directe de BacCollector*.* à la racine
				Local $bHasBacCollector = False
				Local $hSearch = FileFindFirstFile($sNewDrive & "\BacCollector*.*")
				If $hSearch <> -1 Then
					$bHasBacCollector = True
					FileClose($hSearch)
				EndIf

				; Lancer UsbWatcher.exe seulement si BacCollector absent
				If Not $bHasBacCollector And FileExists(@ScriptDir & "\BacBackup_UsbWatcher.exe") Then
					ShellExecute(@ScriptDir & "\BacBackup_UsbWatcher.exe", $sNewDrive & " " & $DossierSession)
				EndIf
			EndIf
			_UpdateDrives()
	EndSwitch
EndFunc   ;==>OnDeviceChange
;#########################################################################################

Func _FindNewDrive()
	Local $aTempDrives = DriveGetDrive("REMOVABLE")

	If Not IsArray($aTempDrives) Then Return ""

	For $i = 1 To $aTempDrives[0]
		Local $bIsOld = False

		If IsArray($g_aDrives) Then
			For $j = 1 To $g_aDrives[0]
				If $g_aDrives[$j] = $aTempDrives[$i] Then
					$bIsOld = True
					ExitLoop
				EndIf
			Next
		EndIf

		If Not $bIsOld Then Return $aTempDrives[$i]
	Next

	Return ""
EndFunc   ;==>_FindNewDrive

;#########################################################################################

Func _UpdateDrives()
	$g_aDrives = DriveGetDrive("REMOVABLE")
	If @error Then $g_aDrives = 0
EndFunc   ;==>_UpdateDrives

;#########################################################################################
;#########################################################################################

Func _GestionDoubleClicTray()
    ; Vérifie si la touche SHIFT (Code 10) est enfoncée
    If _IsPressed("10") Then
        AfficherInterface()
    Else
        ; Comportement si on double-clique SANS Shift
		LancerSauvegardeForcee()
    EndIf
EndFunc   ;==>_GestionDoubleClicTray
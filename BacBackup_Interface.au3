#NoTrayIcon
#Region ;**** Directives AutoIt3Wrapper ****
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/rm /sf /sv
#AutoIt3Wrapper_UseUpx=n
#EndRegion

#Region ;**** Métadonnées de l'application ****
#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup - Interface d'administration)
#pragma compile(FileVersion, 3.0.26.513)
#pragma compile(ProductVersion, 3.0.26.513)
#pragma compile(ProductName, BacBackup)
#pragma compile(InternalName, BacBackup_Interface)
#pragma compile(OriginalFilename, BacBackup_Interface.exe)
#pragma compile(AutoItExecuteAllowed, false)
#pragma compile(InputBoxRes, true)
#pragma compile(Compatibility, vista, win7, win8, win10, win11)
#pragma compile(Console, false)
#EndRegion

#Region ;**** Informations légales ****
#pragma compile(LegalCopyright, © 2016-2026 Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments, Interface d'administration BacBackup - refonte 2026)
#pragma compile(CompanyName, CTEI - Communauté Tunisienne des Enseignants d'Informatique)
#EndRegion

#Region ;**** Configuration de sortie ****
#pragma compile(Out, Installer\Files\BacBackup_Interface.exe)
#EndRegion

; =============================================================================
; BacBackup_Interface.au3 — Refonte 2026
; -----------------------------------------------------------------------------
; Architecture :
;   • Sidebar à gauche (6 onglets)
;   • Tableau de bord par défaut (au lieu de "Dossiers Surveillés")
;   • Cartes métriques en haut, actions rapides, état des composants,
;     activité récente, footer informatif
;   • Paramètres ÉDITABLES (avec sauvegarde au clic)
;   • DPI-aware (SetProcessDPIAware + redimensionnement actif)
;   • Police Segoe UI (Windows 10/11 native)
;
; Palette (cohérente avec la maquette HTML) :
;   Background secondaire : 0xF1EFE8
;   Surface primaire      : 0xFFFFFF
;   Bordure               : 0xE5E2D8
;   Texte primaire        : 0x2C2C2A
;   Texte secondaire      : 0x5F5E5A
;   Accent info           : 0x185FA5
;   Succès (vert)         : 0x3B6D11
;   Warning (orange)      : 0x854F0B
; =============================================================================

#include <WinAPIFiles.au3>
#include <ListViewConstants.au3>
#include <File.au3>
#include <FileConstants.au3>
#include <Array.au3>
#include <GuiConstants.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <StringConstants.au3>
#include <GuiListView.au3>
#include <Date.au3>
#include <Misc.au3>
#include "Utils.au3"

; =============================================================================
; PALETTE & TYPOGRAPHIE
; =============================================================================
Global Const $CLR_BG_SECONDARY = 0xF1EFE8
Global Const $CLR_BG_PRIMARY   = 0xFFFFFF
Global Const $CLR_BORDER       = 0xE5E2D8
Global Const $CLR_TXT_PRIMARY  = 0x2C2C2A
Global Const $CLR_TXT_SECOND   = 0x5F5E5A
Global Const $CLR_TXT_TERTIARY = 0x888780
Global Const $CLR_ACCENT_INFO  = 0x185FA5
Global Const $CLR_BG_INFO      = 0xE6F1FB
Global Const $CLR_SUCCESS      = 0x3B6D11
Global Const $CLR_BG_SUCCESS   = 0xEAF3DE
Global Const $CLR_WARNING      = 0x854F0B
Global Const $CLR_BG_WARNING   = 0xFAEEDA
Global Const $CLR_DANGER       = 0xA32D2D
Global Const $CLR_BG_DANGER    = 0xFCEBEB

Global Const $FONT_FAMILY = "Segoe UI"

; =============================================================================
; LAYOUT
; =============================================================================
Global Const $WIN_W = 820, $WIN_H = 540
Global Const $SIDEBAR_W = 180
Global Const $HEADER_H = 60
Global Const $FOOTER_H = 32

; =============================================================================
; ÉTAT GLOBAL
; =============================================================================
Global $g_hMainGUI
Global $g_hCurrentPanel = 0
Global $g_aPanels[7]            ; 0=Dashboard 1=Dossiers 2=Sessions 3=USB 4=Presse-papier 5=Paramètres 6=À propos
Global $g_aSidebarLinks[7]
Global $g_iCurrentTab = 0
Global $g_sCheminSauve = ""
Global $g_sDossierSession = ""
Global $g_sIniFile = ""
Global $g_sProgVersion = ""
Global $g_idStatusPill, $g_idStatusDot
Global $g_idMetric_Captures, $g_idMetric_NextSave, $g_idMetric_Sessions, $g_idMetric_FreeSpace
Global $g_idListeFichiers = 0  ; ListView des dossiers surveillés (panel 1)
Global $g_idListeSessions = 0  ; ListView des sessions (panel 2)
Global $g_idSessionsTotal = 0  ; Label "Total" sous la liste des sessions
Global $g_iSessionsTotalBytes = 0, $g_iSessionsTotalCount = 0
Global $g_iSessionsSortCol = -1, $g_bSessionsSortAsc = True
Global $g_idListeUSB = 0       ; ListView des événements USB (panel 3)
Global $g_idEditClipboard = 0  ; Edit du presse-papier (panel 4)
; Caches pour éviter de rafraîchir inutilement
Global $g_iCacheUSBCount = -1
Global $g_iCacheClipboardMtime = 0
Global $g_iCacheDossiersStamp = ""
Global $g_idInputIntervalSauve, $g_idInputIntervalCapt
Global $g_idInputTailleMax, $g_idInputNombreMax
Global $g_idBtnSaveSettings = 0
Global $g_idBtnResetSettings = 0
; Boutons d'action du dashboard
Global $g_idBtnForcedBackup = 0
Global $g_idBtnOpenSession = 0
; Footer cliquable (chemin de session)
Global $g_idFooterPath = 0
Global $g_idSessionPath = 0   ; lien cliquable du chemin complet de la session (dashboard)
Global $g_idLinkGitHub = 0, $g_idLinkMail = 0

; Force le DPI-aware pour éviter le rendu flou sur écrans HD
DllCall("user32.dll", "bool", "SetProcessDPIAware")

; =============================================================================
; POINT D'ENTRÉE
; =============================================================================
_KillOtherScript()

; Vérification du mot de passe (préservée de l'ancienne version)
If Not _CheckPassword() Then Exit

; Détermination du chemin de sauvegarde
If $CMDLINE[0] Then $g_sCheminSauve = $CMDLINE[1]
If Not FileExists($g_sCheminSauve) Then
    $g_sCheminSauve = StringUpper(LecteurSauvegarde()) & "Sauvegardes\BacBackup"
EndIf

$g_sIniFile = $g_sCheminSauve & "\BacBackup.ini"
$g_sDossierSession = IniRead($g_sIniFile, "Params", "DossierSession", "")
$g_sProgVersion = FileGetVersion(@ScriptFullPath)

GUIRegisterMsg($WM_NOTIFY, "_WM_NOTIFY")
_BuildMainGUI()
_MainLoop()

Exit


; =============================================================================
; AUTHENTIFICATION (préservée mais relookée)
; =============================================================================
Func _CheckPassword()
    ; Bypass pour BacCollector (préservé)
    If $CMDLINE[0] >= 1 Then
        For $i = 1 To $CMDLINE[0]
            If StringLower($CMDLINE[$i]) = "baccollector" Then Return True
        Next
    EndIf

    Local $sSecurityFile = @ScriptDir & "\Security.ini"
    Local $sPasswordHash = "516623ABD538987FAE1E72A38452C908" ; super password (préservé)

    If FileExists($sSecurityFile) Then
        Local $sStored = IniRead($sSecurityFile, "Security", "PasswordHash", "")
        If $sStored <> "" And StringLen($sStored) = 32 Then $sPasswordHash = $sStored
    EndIf

    Local $hGUI = GUICreate("BacBackup - Authentification", 420, 180, -1, -1, -1, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
    GUISetBkColor($CLR_BG_PRIMARY)

    GUICtrlCreateIcon(@ScriptDir & "\res\Logo01-Interface.ico", -1, 20, 20, 48, 48)

    Local $idTitle = GUICtrlCreateLabel("Authentification requise", 85, 25, 320, 24)
    GUICtrlSetFont($idTitle, 13, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)

    Local $idHint = GUICtrlCreateLabel("Saisissez le mot de passe administrateur pour accéder à l'interface.", 85, 50, 320, 32)
    GUICtrlSetFont($idHint, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_SECOND)

    Local $idPwd = GUICtrlCreateInput("", 85, 95, 315, 28, $ES_PASSWORD)
    GUICtrlSetFont($idPwd, 10, 400, 0, $FONT_FAMILY)

    Local $idOK = GUICtrlCreateButton("Valider", 220, 135, 90, 30)
    GUICtrlSetFont($idOK, 9, 600, 0, $FONT_FAMILY)
    GUICtrlSetState($idOK, $GUI_DEFBUTTON)

    Local $idCancel = GUICtrlCreateButton("Annuler", 315, 135, 90, 30)
    GUICtrlSetFont($idCancel, 9, 400, 0, $FONT_FAMILY)

    GUISetState(@SW_SHOW, $hGUI)
    GUICtrlSetState($idPwd, $GUI_FOCUS)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $idCancel
                GUIDelete($hGUI)
                Return False
            Case $idOK
                Local $sPwd = GUICtrlRead($idPwd)
                If StringUpper(_MD5ForString($sPwd)) = StringUpper($sPasswordHash) Then
                    GUIDelete($hGUI)
                    Return True
                Else
                    GUIDelete($hGUI)
                    MsgBox(16 + 262144, "Accès refusé", "Mot de passe incorrect.", 3)
                    Return False
                EndIf
        EndSwitch
    WEnd
EndFunc   ;==>_CheckPassword


; =============================================================================
; CONSTRUCTION DE LA FENÊTRE PRINCIPALE
; =============================================================================
Func _BuildMainGUI()
    $g_hMainGUI = GUICreate("BacBackup " & $g_sProgVersion, $WIN_W, $WIN_H, -1, -1, _
            BitOR($WS_OVERLAPPEDWINDOW, $WS_CLIPCHILDREN))
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    _BuildHeader()
    _BuildSidebar()
    _BuildAllPanels()
    _BuildFooter()

    ; Onglet par défaut : Dashboard
    _SwitchTab(0)

    GUISetState(@SW_SHOW, $g_hMainGUI)
EndFunc   ;==>_BuildMainGUI


; ─── Header ────────────────────────────────────────────────────────────────
Func _BuildHeader()
    ; Bandeau supérieur blanc avec logo + titre + pill de statut
    GUICtrlCreateLabel("", 0, 0, $WIN_W, $HEADER_H)
    GUICtrlSetBkColor(-1, $CLR_BG_PRIMARY)
    GUICtrlSetState(-1, $GUI_DISABLE)

    ; Logo (carré bleu clair avec icône)
    GUICtrlCreateLabel("", 16, 14, 32, 32)
    GUICtrlSetBkColor(-1, $CLR_BG_INFO)

    GUICtrlCreateIcon(@ScriptDir & "\res\Logo01-Interface.ico", -1, 18, 16, 28, 28)

    ; Titre + sous-titre
    Local $idTitle = GUICtrlCreateLabel("BacBackup", 60, 12, 250, 18)
    GUICtrlSetFont($idTitle, 11, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)

    Local $idSubtitle = GUICtrlCreateLabel("v " & $g_sProgVersion & " · session " & $g_sDossierSession, 60, 32, 500, 16)
    GUICtrlSetFont($idSubtitle, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idSubtitle, $CLR_TXT_TERTIARY)

    ; Pill de statut "Surveillance active"
    $g_idStatusDot = GUICtrlCreateLabel("", $WIN_W - 175, 22, 8, 8)
    GUICtrlSetBkColor($g_idStatusDot, $CLR_SUCCESS)

    $g_idStatusPill = GUICtrlCreateLabel("Surveillance active", $WIN_W - 160, 18, 145, 20, $SS_LEFT)
    GUICtrlSetFont($g_idStatusPill, 8, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($g_idStatusPill, $CLR_SUCCESS)
    GUICtrlSetBkColor($g_idStatusPill, $CLR_BG_SUCCESS)

    ; Ligne de séparation sous le header
    GUICtrlCreateLabel("", 0, $HEADER_H - 1, $WIN_W, 1)
    GUICtrlSetBkColor(-1, $CLR_BORDER)
EndFunc   ;==>_BuildHeader


; ─── Sidebar ───────────────────────────────────────────────────────────────
Func _BuildSidebar()
    ; Fond de la sidebar
    GUICtrlCreateLabel("", 0, $HEADER_H, $SIDEBAR_W, $WIN_H - $HEADER_H - $FOOTER_H)
    GUICtrlSetBkColor(-1, $CLR_BG_PRIMARY)
    GUICtrlSetState(-1, $GUI_DISABLE)

    ; Ligne de séparation à droite de la sidebar
    GUICtrlCreateLabel("", $SIDEBAR_W - 1, $HEADER_H, 1, $WIN_H - $HEADER_H - $FOOTER_H)
    GUICtrlSetBkColor(-1, $CLR_BORDER)

    ; Items
    Local $aLabels[7] = ["Tableau de bord", "Dossiers surveillés", "Sessions", _
            "Événements USB", "Presse-papier", "Paramètres", "À propos"]
    Local $aIcons[7] = [137, 4, 297, 7, 134, 22, 24] ; index shell32.dll

    Local $iY = $HEADER_H + 12
    For $i = 0 To 6
        ; Séparateur visuel avant "À propos" (item 6) pour le distinguer des actions principales
        If $i = 6 Then
            GUICtrlCreateLabel("", 14, $iY + 4, $SIDEBAR_W - 28, 1)
            GUICtrlSetBkColor(-1, $CLR_BORDER)
            $iY += 12
        EndIf
        $g_aSidebarLinks[$i] = _CreateSidebarItem($aLabels[$i], $aIcons[$i], $iY, $i)
        $iY += 32
    Next
EndFunc   ;==>_BuildSidebar

Func _CreateSidebarItem($sLabel, $iIconIdx, $iY, $iIndex)
    ; Icône
    GUICtrlCreateIcon("shell32.dll", $iIconIdx, 14, $iY + 4, 16, 16)

    ; Label cliquable
    Local $idLabel = GUICtrlCreateLabel("  " & $sLabel, 36, $iY, $SIDEBAR_W - 40, 24, $SS_LEFT + $SS_NOTIFY + $SS_CENTERIMAGE)
    GUICtrlSetFont($idLabel, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idLabel, $CLR_TXT_SECOND)
    GUICtrlSetBkColor($idLabel, $CLR_BG_PRIMARY)
    GUICtrlSetCursor($idLabel, 0)

    Return $idLabel
EndFunc   ;==>_CreateSidebarItem


; ─── Footer ────────────────────────────────────────────────────────────────
Func _BuildFooter()
    Local $iY = $WIN_H - $FOOTER_H

    GUICtrlCreateLabel("", 0, $iY, $WIN_W, 1)
    GUICtrlSetBkColor(-1, $CLR_BORDER)

    GUICtrlCreateLabel("", 0, $iY + 1, $WIN_W, $FOOTER_H - 1)
    GUICtrlSetBkColor(-1, $CLR_BG_PRIMARY)
    GUICtrlSetState(-1, $GUI_DISABLE)

    Local $sIntervalSauve = IniRead($g_sIniFile, "Params", "IntervalleInterSauvegardesEnMinutes", "2")
    Local $sIntervalCapt = IniRead($g_sIniFile, "Params", "IntervalleInterCapturesEnSecondes", "5")

    $g_idFooterPath = GUICtrlCreateLabel($g_sCheminSauve & "\" & $g_sDossierSession, 16, $iY + 9, 480, 18, _
            $SS_LEFT + $SS_NOTIFY)
    GUICtrlSetFont($g_idFooterPath, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($g_idFooterPath, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($g_idFooterPath, $CLR_BG_PRIMARY)
    GUICtrlSetCursor($g_idFooterPath, 0)
    GUICtrlSetTip($g_idFooterPath, "Cliquer pour ouvrir le dossier de la session courante")

    Local $idRight = GUICtrlCreateLabel("Capture toutes les " & $sIntervalCapt & " s · Sauvegarde toutes les " _
            & $sIntervalSauve & " min", $WIN_W - 320, $iY + 9, 304, 18, $SS_RIGHT)
    GUICtrlSetFont($idRight, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idRight, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idRight, $CLR_BG_PRIMARY)
EndFunc   ;==>_BuildFooter


; =============================================================================
; PANELS — un par onglet
; =============================================================================
Func _BuildAllPanels()
    Local $iX = $SIDEBAR_W
    Local $iY = $HEADER_H
    Local $iW = $WIN_W - $SIDEBAR_W
    Local $iH = $WIN_H - $HEADER_H - $FOOTER_H

    $g_aPanels[0] = _BuildPanel_Dashboard($iX, $iY, $iW, $iH)
    $g_aPanels[1] = _BuildPanel_Dossiers($iX, $iY, $iW, $iH)
    $g_aPanels[2] = _BuildPanel_Sessions($iX, $iY, $iW, $iH)
    $g_aPanels[3] = _BuildPanel_USB($iX, $iY, $iW, $iH)
    $g_aPanels[4] = _BuildPanel_Clipboard($iX, $iY, $iW, $iH)
    $g_aPanels[5] = _BuildPanel_Settings($iX, $iY, $iW, $iH)
    $g_aPanels[6] = _BuildPanel_About($iX, $iY, $iW, $iH)
EndFunc   ;==>_BuildAllPanels


; ─── Panel 0 : DASHBOARD (par défaut) ──────────────────────────────────────
Func _BuildPanel_Dashboard($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    Local $iPad = 18

    ; ─── Titre de la session courante (gros et clair) ───
    Local $idSessionLbl = GUICtrlCreateLabel("Session courante", $iPad, 14, $iW - $iPad * 2, 14)
    GUICtrlSetFont($idSessionLbl, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idSessionLbl, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idSessionLbl, $CLR_BG_PRIMARY)

    ; Chemin complet de la session (cliquable, sans style hyperlien)
    Local $sFullPath = $g_sCheminSauve & "\" & $g_sDossierSession
    $g_idSessionPath = GUICtrlCreateLabel($sFullPath, $iPad, 32, $iW - $iPad * 2, 24, $SS_LEFT + $SS_NOTIFY)
    GUICtrlSetFont($g_idSessionPath, 12, 600, 0, $FONT_FAMILY) ; 12pt gras, NON souligné
    GUICtrlSetColor($g_idSessionPath, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($g_idSessionPath, $CLR_BG_PRIMARY)
    GUICtrlSetCursor($g_idSessionPath, 0)
    GUICtrlSetTip($g_idSessionPath, "Cliquer pour ouvrir le dossier dans l'Explorateur")

    ; Séparateur sous le titre
    GUICtrlCreateLabel("", $iPad, 64, $iW - $iPad * 2, 1)
    GUICtrlSetBkColor(-1, $CLR_BORDER)

    ; ─── 4 cartes métriques ───
    Local $iCardY = 80
    Local $iCardW = ($iW - $iPad * 2 - 30) / 4 ; 4 cartes + 3 gaps de 10
    Local $iCardH = 64

    ; Détecter la lettre du lecteur utilisé pour l'affichage dynamique
    Local $sDriveLetter = StringUpper(StringLeft($g_sCheminSauve, 1)) & ":"

    _BuildMetricCard($iPad,                              $iCardY, $iCardW, $iCardH, "Captures (session)",     "—", "calcul...")
    _BuildMetricCard($iPad + ($iCardW + 10),            $iCardY, $iCardW, $iCardH, "Prochaine sauvegarde",   "—", "selon activité")
    _BuildMetricCard($iPad + ($iCardW + 10) * 2,        $iCardY, $iCardW, $iCardH, "Sessions stockées",      "—", "—")
    _BuildMetricCard($iPad + ($iCardW + 10) * 3,        $iCardY, $iCardW, $iCardH, "Espace libre " & $sDriveLetter, "—", "—")

    ; ─── Boutons d'action rapides ───
    Local $iBY = $iCardY + $iCardH + 18
    $g_idBtnOpenSession  = _BuildActionButton($iPad,        $iBY, "Ouvrir dossier Session", True)   ; bouton primaire (bleu)
    $g_idBtnForcedBackup = _BuildActionButton($iPad + 180,  $iBY, "Sauvegarde forcée",   False)

    ; ─── Carte "État des composants" (pleine largeur) ───
    Local $iStateY = $iBY + 44
    _BuildComponentStatusCard($iPad, $iStateY, $iW - $iPad * 2, $iH - $iStateY - 12)

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_Dashboard


Func _BuildMetricCard($iX, $iY, $iW, $iH, $sLabel, $sValue, $sHint)
    ; Fond gris très clair
    GUICtrlCreateLabel("", $iX, $iY, $iW, $iH)
    GUICtrlSetBkColor(-1, $CLR_BG_SECONDARY)

    Local $idLabel = GUICtrlCreateLabel($sLabel, $iX + 10, $iY + 8, $iW - 20, 14)
    GUICtrlSetFont($idLabel, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idLabel, $CLR_TXT_SECOND)
    GUICtrlSetBkColor($idLabel, $CLR_BG_SECONDARY)

    Local $idValue = GUICtrlCreateLabel($sValue, $iX + 10, $iY + 22, $iW - 20, 24)
    GUICtrlSetFont($idValue, 14, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idValue, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idValue, $CLR_BG_SECONDARY)

    Local $idHint = GUICtrlCreateLabel($sHint, $iX + 10, $iY + 46, $iW - 20, 14)
    GUICtrlSetFont($idHint, 7, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHint, $CLR_BG_SECONDARY)

    ; On retient l'ID de la valeur pour mises à jour live
    ; Note : le label "Espace libre" contient une lettre de lecteur variable,
    ; donc on utilise StringInStr plutôt qu'un match exact.
    Switch $sLabel
        Case "Captures (session)"
            $g_idMetric_Captures = $idValue
        Case "Prochaine sauvegarde"
            $g_idMetric_NextSave = $idValue
        Case "Sessions stockées"
            $g_idMetric_Sessions = $idValue
        Case Else
            If StringInStr($sLabel, "Espace libre") Then $g_idMetric_FreeSpace = $idValue
    EndSwitch
EndFunc   ;==>_BuildMetricCard


Func _BuildActionButton($iX, $iY, $sLabel, $bPrimary = False)
    ; Largeur calibrée pour laisser ~15px de marge entre texte et bordure
    Local $iBtnW = $bPrimary ? 170 : 145
    Local $idBtn = GUICtrlCreateButton($sLabel, $iX, $iY, $iBtnW, 32, $BS_FLAT)
    GUICtrlSetFont($idBtn, 9, ($bPrimary ? 600 : 500), 0, $FONT_FAMILY)
    If $bPrimary Then
        ; Bouton primaire : fond bleu accent, texte blanc
        GUICtrlSetBkColor($idBtn, $CLR_ACCENT_INFO)
        GUICtrlSetColor($idBtn, 0xFFFFFF)
    Else
        ; Bouton standard : fond blanc, texte primaire
        GUICtrlSetBkColor($idBtn, $CLR_BG_PRIMARY)
        GUICtrlSetColor($idBtn, $CLR_TXT_PRIMARY)
    EndIf
    GUICtrlSetTip($idBtn, $sLabel)
    Return $idBtn
EndFunc   ;==>_BuildActionButton


Func _BuildComponentStatusCard($iX, $iY, $iW, $iH)
    ; Cadre de la carte
    GUICtrlCreateLabel("", $iX, $iY, $iW, $iH)
    GUICtrlSetBkColor(-1, $CLR_BG_PRIMARY)

    Local $idTitle = GUICtrlCreateLabel("État des composants", $iX + 14, $iY + 12, $iW - 28, 18)
    GUICtrlSetFont($idTitle, 10, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    ; 4 lignes d'état
    Local $aRows[4][3] = [ _
            ["Service Watchdog (BBMonSvc)", _CheckWatchdog(),         _GetWatchdogPID()], _
            ["Listener presse-papier",      _CheckClipboardListener(), _CountClipboardEntries()], _
            ["Surveillance USB",             _CheckUSBMonitoring(),     _CountUSBAlerts()], _
            ["Verrou ACL Sauvegardes",       _CheckACLLock(),           ""] _
    ]

    Local $iRowY = $iY + 38
    For $i = 0 To 3
        _BuildStatusRow($iX + 14, $iRowY, $iW - 28, $aRows[$i][0], $aRows[$i][1], $aRows[$i][2])
        $iRowY += 32
        If $i < 3 Then
            GUICtrlCreateLabel("", $iX + 14, $iRowY - 4, $iW - 28, 1)
            GUICtrlSetBkColor(-1, $CLR_BORDER)
        EndIf
    Next
EndFunc   ;==>_BuildComponentStatusCard


Func _BuildStatusRow($iX, $iY, $iW, $sLabel, $iStatus, $sExtra)
    ; $iStatus : 1 = OK (vert), 2 = warning (orange), 3 = error (rouge)
    Local $sStatusChar, $iStatusColor
    Switch $iStatus
        Case 1
            $sStatusChar = "✓"
            $iStatusColor = $CLR_SUCCESS
        Case 2
            $sStatusChar = "!"
            $iStatusColor = $CLR_WARNING
        Case Else
            $sStatusChar = "✗"
            $iStatusColor = $CLR_DANGER
    EndSwitch

    Local $idStatus = GUICtrlCreateLabel($sStatusChar, $iX, $iY, 16, 18, $SS_CENTER)
    GUICtrlSetFont($idStatus, 11, 700, 0, $FONT_FAMILY)
    GUICtrlSetColor($idStatus, $iStatusColor)
    GUICtrlSetBkColor($idStatus, $CLR_BG_PRIMARY)

    Local $idLabel = GUICtrlCreateLabel($sLabel, $iX + 22, $iY + 1, $iW - 110, 18)
    GUICtrlSetFont($idLabel, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idLabel, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idLabel, $CLR_BG_PRIMARY)

    Local $idExtra = GUICtrlCreateLabel($sExtra, $iX + $iW - 100, $iY + 1, 100, 18, $SS_RIGHT)
    GUICtrlSetFont($idExtra, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idExtra, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idExtra, $CLR_BG_PRIMARY)
EndFunc   ;==>_BuildStatusRow


; ─── Panel 1 : DOSSIERS SURVEILLÉS ────────────────────────────────────────
Func _BuildPanel_Dossiers($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    Local $idTitle = GUICtrlCreateLabel("Dossiers surveillés", 18, 18, $iW - 36, 22)
    GUICtrlSetFont($idTitle, 12, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    Local $idHint = GUICtrlCreateLabel("Double-cliquez sur un dossier pour l'ouvrir dans l'Explorateur.", 18, 42, $iW - 36, 16)
    GUICtrlSetFont($idHint, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHint, $CLR_BG_PRIMARY)

    $g_idListeFichiers = GUICtrlCreateListView("N°|Dossier", 18, 70, $iW - 36, $iH - 90, _
            $LVS_REPORT, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($g_idListeFichiers, 0, 50)
    _GUICtrlListView_SetColumnWidth($g_idListeFichiers, 1, $iW - 110)

    _RemplirListeDossiers()

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_Dossiers


Func _RemplirListeDossiers()
    _GUICtrlListView_DeleteAllItems($g_idListeFichiers)

    Local $aListe[1] = [0]
    Local $aTmp

    $aTmp = _DossiersTravailEleves()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)

    $aTmp = _DossiersSurBureau()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)

    $aTmp = DossiersEasyPHPwww()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)

    $aTmp = DossiersEasyPHPdata()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)

    For $i = 1 To $aListe[0]
        GUICtrlCreateListViewItem($i & "|" & $aListe[$i], $g_idListeFichiers)
    Next
EndFunc   ;==>_RemplirListeDossiers


Func _AppendArray(ByRef $aDest, $aSrc)
    For $i = 1 To $aSrc[0]
        $aDest[0] += 1
        ReDim $aDest[$aDest[0] + 1]
        $aDest[$aDest[0]] = $aSrc[$i]
    Next
EndFunc   ;==>_AppendArray


; ─── Panel 2 : SESSIONS ────────────────────────────────────────────────────
Func _BuildPanel_Sessions($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    Local $idTitle = GUICtrlCreateLabel("Sessions de sauvegarde", 18, 18, $iW - 36, 22)
    GUICtrlSetFont($idTitle, 12, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    Local $idHint = GUICtrlCreateLabel("Toutes les sessions sur tous les lecteurs. Cliquez sur une entête pour trier. Double-cliquez pour ouvrir le dossier.", _
            18, 42, $iW - 36, 16)
    GUICtrlSetFont($idHint, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHint, $CLR_BG_PRIMARY)

    ; ListView (hauteur réduite pour laisser place au footer)
    $g_idListeSessions = GUICtrlCreateListView("Lecteur|Session|Date|Captures|Taille", 18, 70, $iW - 36, $iH - 110, _
            $LVS_REPORT, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($g_idListeSessions, 0, 60)
    _GUICtrlListView_SetColumnWidth($g_idListeSessions, 1, 200)
    _GUICtrlListView_SetColumnWidth($g_idListeSessions, 2, 110)
    _GUICtrlListView_SetColumnWidth($g_idListeSessions, 3, 80)
    _GUICtrlListView_SetColumnWidth($g_idListeSessions, 4, 80)

    _RemplirListeSessions($g_idListeSessions)

    ; Footer avec le total
    $g_idSessionsTotal = GUICtrlCreateLabel("", 18, $iH - 32, $iW - 36, 18)
    GUICtrlSetFont($g_idSessionsTotal, 9, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($g_idSessionsTotal, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($g_idSessionsTotal, $CLR_BG_PRIMARY)
    _UpdateSessionsTotalLabel()

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_Sessions


Func _RemplirListeSessions($idLV)
    ; Vider la liste avant remplissage (utile pour le refresh live)
    _GUICtrlListView_DeleteAllItems($idLV)

    Local $iTotalBytes = 0
    Local $iTotalCount = 0

    ; Parcourt TOUS les lecteurs fixes pour trouver les dossiers de session
    Local $aDrives = DriveGetDrive('FIXED')
    If IsArray($aDrives) Then
        For $i = 1 To $aDrives[0]
            If DriveGetType($aDrives[$i], $DT_BUSTYPE) = "USB" Then ContinueLoop

            Local $sDrive = StringUpper($aDrives[$i])
            Local $sBacBackup = $sDrive & "\Sauvegardes\BacBackup"
            If Not FileExists($sBacBackup) Then ContinueLoop

            Local $aSessions = _FileListToArray($sBacBackup, "*", 2, False)
            If Not IsArray($aSessions) Then ContinueLoop

            For $j = $aSessions[0] To 1 Step -1
                Local $sSession = $aSessions[$j]

                ; Date au format ISO aaaa-mm-jj depuis "001___24_5_2026___10h30"
                Local $sDate = ""
                Local $aParts = StringSplit($sSession, "___", $STR_ENTIRESPLIT)
                If $aParts[0] >= 2 Then
                    Local $aDateParts = StringSplit($aParts[2], "_", $STR_NOCOUNT)
                    If UBound($aDateParts) >= 3 Then
                        ; aDateParts = [jour, mois, année]
                        $sDate = $aDateParts[2] & "-" & _
                                StringFormat("%02d", Number($aDateParts[1])) & "-" & _
                                StringFormat("%02d", Number($aDateParts[0]))
                    Else
                        $sDate = $aParts[2]
                    EndIf
                EndIf

                Local $sFullPath = $sBacBackup & "\" & $sSession
                Local $sCapDir = $sFullPath & "\_CapturesEcran"
                Local $iCaptures = 0
                If FileExists($sCapDir) Then
                    Local $aCap = _FileListToArray($sCapDir, "*.png", 1, False)
                    If IsArray($aCap) Then $iCaptures = $aCap[0]
                EndIf

                Local $iSize = DirGetSize($sFullPath)
                $iTotalBytes += $iSize
                $iTotalCount += 1

                GUICtrlCreateListViewItem($sDrive & "|" & $sSession & "|" & $sDate & "|" _
                        & $iCaptures & "|" & _FineSize($iSize), $idLV)
            Next
        Next
    EndIf

    ; Stocker pour le footer total
    $g_iSessionsTotalBytes = $iTotalBytes
    $g_iSessionsTotalCount = $iTotalCount
EndFunc   ;==>_RemplirListeSessions


Func _UpdateSessionsTotalLabel()
    If $g_idSessionsTotal = 0 Then Return
    Local $sText = $g_iSessionsTotalCount & " session" & ($g_iSessionsTotalCount > 1 ? "s" : "") & _
            "  ·  Taille totale : " & _FineSize($g_iSessionsTotalBytes)
    GUICtrlSetData($g_idSessionsTotal, $sText)
EndFunc   ;==>_UpdateSessionsTotalLabel


; -----------------------------------------------------------------------------
; _TriListeSessions : tri la ListView Sessions sur la colonne $iCol
; Le sens alterne à chaque clic (ascendant ↔ descendant).
; UN SEUL CHEMIN : tri à bulles avec comparateur adapté selon la colonne.
; On évite _GUICtrlListView_SimpleSort qui a son propre toggle interne,
; lequel se désynchronise avec notre $g_bSessionsSortAsc.
; -----------------------------------------------------------------------------
Func _TriListeSessions($iCol)
    ; Inverser le sens si on reclique sur la même colonne
    If $g_iSessionsSortCol = $iCol Then
        $g_bSessionsSortAsc = Not $g_bSessionsSortAsc
    Else
        $g_iSessionsSortCol = $iCol
        $g_bSessionsSortAsc = True
    EndIf

    Local $iCount = _GUICtrlListView_GetItemCount($g_idListeSessions)
    If $iCount < 2 Then Return

    ; Snapshot des 5 colonnes de chaque ligne
    Local $aData[$iCount][5]
    For $i = 0 To $iCount - 1
        For $k = 0 To 4
            $aData[$i][$k] = _GUICtrlListView_GetItemText($g_idListeSessions, $i, $k)
        Next
    Next

    ; Tri à bulles (acceptable pour quelques centaines de sessions max)
    Local $bIsNumeric = ($iCol = 3 Or $iCol = 4) ; Captures, Taille
    For $i = 0 To $iCount - 2
        For $j = 0 To $iCount - $i - 2
            Local $iCmp = _CompareSessionsCol($aData[$j][$iCol], $aData[$j + 1][$iCol], $bIsNumeric)
            Local $bSwap = $g_bSessionsSortAsc ? ($iCmp > 0) : ($iCmp < 0)
            If $bSwap Then
                For $k = 0 To 4
                    Local $sTmp = $aData[$j][$k]
                    $aData[$j][$k] = $aData[$j + 1][$k]
                    $aData[$j + 1][$k] = $sTmp
                Next
            EndIf
        Next
    Next

    ; Réécrire la ListView
    _GUICtrlListView_DeleteAllItems($g_idListeSessions)
    For $i = 0 To $iCount - 1
        GUICtrlCreateListViewItem($aData[$i][0] & "|" & $aData[$i][1] & "|" & $aData[$i][2] _
                & "|" & $aData[$i][3] & "|" & $aData[$i][4], $g_idListeSessions)
    Next
EndFunc   ;==>_TriListeSessions


; -----------------------------------------------------------------------------
; _CompareSessionsCol : retourne -1, 0 ou 1 (style strcmp)
; - Si numérique → compare la valeur numérique parsée (Captures = entier,
;   Taille = "1.2 Go" → octets)
; - Sinon → strict StringCompare sur le texte affiché (insensible à la casse)
; -----------------------------------------------------------------------------
Func _CompareSessionsCol($s1, $s2, $bIsNumeric)
    If $bIsNumeric Then
        Local $iV1 = _ParseValeurNumeriqueColonne($s1)
        Local $iV2 = _ParseValeurNumeriqueColonne($s2)
        If $iV1 < $iV2 Then Return -1
        If $iV1 > $iV2 Then Return 1
        Return 0
    EndIf
    ; Comparaison texte stricte (StringCompare retourne déjà -1/0/1)
    Return StringCompare($s1, $s2)
EndFunc   ;==>_CompareSessionsCol


Func _ParseValeurNumeriqueColonne($sText)
    ; Cas 1 : nombre entier simple ("42") → Captures
    If StringRegExp($sText, "^\d+$") Then Return Number($sText)

    ; Cas 2 : valeur avec unité ("1.2 Go", "350 Mo", "8.5 Ko") → Taille
    Local $aMatch = StringRegExp($sText, "([\d,.]+)\s*(o|Ko|Mo|Go|To)", 1)
    If Not IsArray($aMatch) Then Return Number($sText)
    Local $iVal = Number(StringReplace($aMatch[0], ",", "."))
    Switch $aMatch[1]
        Case "Ko"
            Return $iVal * 1024
        Case "Mo"
            Return $iVal * 1024 * 1024
        Case "Go"
            Return $iVal * 1024 * 1024 * 1024
        Case "To"
            Return $iVal * 1024 * 1024 * 1024 * 1024
        Case Else
            Return $iVal
    EndSwitch
EndFunc   ;==>_ParseValeurNumeriqueColonne


; ─── Panel 3 : ÉVÉNEMENTS USB ─────────────────────────────────────────────
Func _BuildPanel_USB($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    Local $idTitle = GUICtrlCreateLabel("Événements USB", 18, 18, $iW - 36, 22)
    GUICtrlSetFont($idTitle, 12, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    Local $idHint = GUICtrlCreateLabel("Clés USB non autorisées détectées dans la session courante.", 18, 42, $iW - 36, 16)
    GUICtrlSetFont($idHint, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHint, $CLR_BG_PRIMARY)

    $g_idListeUSB = GUICtrlCreateListView("Heure|Numéro de série|Marque/Modèle|Taille", 18, 70, $iW - 36, $iH - 90, _
            $LVS_REPORT, BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT))
    _GUICtrlListView_SetColumnWidth($g_idListeUSB, 0, 80)
    _GUICtrlListView_SetColumnWidth($g_idListeUSB, 1, 150)
    _GUICtrlListView_SetColumnWidth($g_idListeUSB, 2, 200)
    _GUICtrlListView_SetColumnWidth($g_idListeUSB, 3, 100)

    _RemplirListeUSB($g_idListeUSB)

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_USB


Func _RemplirListeUSB($idLV)
    _GUICtrlListView_DeleteAllItems($idLV)

    Local $sUSBDir = $g_sCheminSauve & "\" & $g_sDossierSession & "\_UsbWatcher"
    If Not FileExists($sUSBDir) Then
        $g_iCacheUSBCount = 0
        Return
    EndIf

    Local $aDirs = _FileListToArray($sUSBDir, "*", 2, False)
    If Not IsArray($aDirs) Then
        $g_iCacheUSBCount = 0
        Return
    EndIf

    $g_iCacheUSBCount = $aDirs[0]

    For $i = 1 To $aDirs[0]
        Local $sDirName = $aDirs[$i]
        ; Format : "14_30_45___SN__ABC12345"
        Local $aParts = StringSplit($sDirName, "___")
        Local $sTime = "", $sSN = ""
        If $aParts[0] >= 1 Then $sTime = StringReplace($aParts[1], "_", ":")
        If $aParts[0] >= 2 Then $sSN = StringReplace($aParts[2], "SN__", "")

        Local $sInfoFile = $sUSBDir & "\" & $sDirName & "\_ContenuCléUSB.txt"
        Local $sBrand = "—", $sSize = "—"
        If FileExists($sInfoFile) Then
            Local $sContent = FileRead($sInfoFile)
            Local $aMatch = StringRegExp($sContent, "Marque/Modèle\s*:\s*([^\r\n]+)", 1)
            If IsArray($aMatch) Then $sBrand = StringStripWS($aMatch[0], 3)
            $aMatch = StringRegExp($sContent, "Capacité[^:]*:\s*([^\r\n]+)", 1)
            If IsArray($aMatch) Then $sSize = StringStripWS($aMatch[0], 3)
        EndIf

        GUICtrlCreateListViewItem($sTime & "|" & $sSN & "|" & $sBrand & "|" & $sSize, $idLV)
    Next
EndFunc   ;==>_RemplirListeUSB


; ─── Panel 4 : PRESSE-PAPIER ───────────────────────────────────────────────
Func _BuildPanel_Clipboard($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    Local $idTitle = GUICtrlCreateLabel("Journal du presse-papier", 18, 18, $iW - 36, 22)
    GUICtrlSetFont($idTitle, 12, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    Local $idHint = GUICtrlCreateLabel("Contenu intégral du journal de la session courante.", 18, 42, $iW - 36, 16)
    GUICtrlSetFont($idHint, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHint, $CLR_BG_PRIMARY)

    $g_idEditClipboard = GUICtrlCreateEdit("", 18, 70, $iW - 36, $iH - 90, _
            BitOR($ES_MULTILINE, $ES_READONLY, $ES_AUTOVSCROLL, $ES_AUTOHSCROLL, $WS_VSCROLL, $WS_HSCROLL))
    GUICtrlSetFont($g_idEditClipboard, 9, 400, 0, "Consolas")
    GUICtrlSetBkColor($g_idEditClipboard, $CLR_BG_PRIMARY)

    _RemplirJournalClipboard()

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_Clipboard


; ─── Panel 5 : PARAMÈTRES (ÉDITABLES) ──────────────────────────────────────
Func _BuildPanel_Settings($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    Local $idTitle = GUICtrlCreateLabel("Paramètres", 18, 18, $iW - 36, 22)
    GUICtrlSetFont($idTitle, 12, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    Local $idHint = GUICtrlCreateLabel("Modifications enregistrées au clic sur ""Enregistrer"". Prennent effet à la prochaine session.", _
            18, 42, $iW - 36, 16)
    GUICtrlSetFont($idHint, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHint, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHint, $CLR_BG_PRIMARY)

    Local $iY2 = 80
    _BuildSettingRow($iY2,       "Intervalle inter-sauvegardes (minutes)",   "IntervalleInterSauvegardesEnMinutes",   "2",  "1 à 15", 0)
    _BuildSettingRow($iY2 + 50,  "Intervalle inter-captures (secondes)",     "IntervalleInterCapturesEnSecondes",     "5",  "2 à 20", 1)
    _BuildSettingRow($iY2 + 100, "Taille maximale du dossier (Go)",          "TailleMaxDuDossierBacBackupEnGigaoctet", "50", "10 à 200", 2)
    _BuildSettingRow($iY2 + 150, "Nombre maximal de sessions",               "NombreMaxDeDossiersDeSauve",            "100", "20 à 500", 3)

    ; Boutons : Restaurer par défaut (secondaire, à gauche) + Enregistrer (primaire, à droite)
    Local $iBtnY = $iY2 + 210

    $g_idBtnResetSettings = GUICtrlCreateButton("Restaurer par défaut", 18, $iBtnY, 160, 32, $BS_FLAT)
    GUICtrlSetFont($g_idBtnResetSettings, 9, 500, 0, $FONT_FAMILY)
    GUICtrlSetBkColor($g_idBtnResetSettings, $CLR_BG_PRIMARY)
    GUICtrlSetColor($g_idBtnResetSettings, $CLR_TXT_PRIMARY)

    $g_idBtnSaveSettings = GUICtrlCreateButton("Enregistrer", $iW - 130, $iBtnY, 110, 32, $BS_FLAT)
    GUICtrlSetFont($g_idBtnSaveSettings, 9, 600, 0, $FONT_FAMILY)
    GUICtrlSetBkColor($g_idBtnSaveSettings, $CLR_ACCENT_INFO)
    GUICtrlSetColor($g_idBtnSaveSettings, 0xFFFFFF)

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_Settings


; ─── Panel 6 : À PROPOS ────────────────────────────────────────────────────
Func _BuildPanel_About($iX, $iY, $iW, $iH)
    Local $hPanel = GUICreate("", $iW, $iH, $iX, $iY, $WS_CHILD + $WS_CLIPCHILDREN, -1, $g_hMainGUI)
    GUISetBkColor($CLR_BG_PRIMARY)
    GUISetFont(9, 400, 0, $FONT_FAMILY)

    ; Logo grand format à gauche
    GUICtrlCreateIcon(@ScriptDir & "\res\Logo01-A-Propos-64x64.ico", -1, 30, 30, 96, 96)

    ; Titre
    Local $idTitle = GUICtrlCreateLabel("BacBackup", 150, 30, 350, 30)
    GUICtrlSetFont($idTitle, 18, 600, 0, $FONT_FAMILY)
    GUICtrlSetColor($idTitle, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idTitle, $CLR_BG_PRIMARY)

    Local $idVersion = GUICtrlCreateLabel("Version " & $g_sProgVersion, 150, 65, 350, 18)
    GUICtrlSetFont($idVersion, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idVersion, $CLR_TXT_SECOND)
    GUICtrlSetBkColor($idVersion, $CLR_BG_PRIMARY)

    ; Copyright
    Local $aFileTime = FileGetTime(@ScriptFullPath)
    Local $sCopyrightYear = (IsArray($aFileTime) ? $aFileTime[0] : @YEAR)
    Local $idCopy = GUICtrlCreateLabel("© 2016-" & $sCopyrightYear & "  Communauté Tunisienne des Enseignants d'Informatique", _
            150, 90, 450, 18)
    GUICtrlSetFont($idCopy, 8, 500, 0, $FONT_FAMILY)
    GUICtrlSetColor($idCopy, $CLR_TXT_SECOND)
    GUICtrlSetBkColor($idCopy, $CLR_BG_PRIMARY)

    ; Séparateur
    GUICtrlCreateLabel("", 30, 145, $iW - 60, 1)
    GUICtrlSetBkColor(-1, $CLR_BORDER)

    ; Description
    Local $idDesc = GUICtrlCreateLabel( _
            "BacBackup est un outil de sauvegarde et de surveillance conçu pour les environnements " & _
            "éducatifs. Il sauvegarde automatiquement les travaux des élèves et capture leur " & _
            "activité à l'écran dans les salles informatiques.", _
            30, 160, $iW - 60, 50)
    GUICtrlSetFont($idDesc, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idDesc, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idDesc, $CLR_BG_PRIMARY)

    ; Liens (style hyperlien natif)
    Local $idLblGH = GUICtrlCreateLabel("Code source et téléchargement :", 30, 230, 220, 18)
    GUICtrlSetFont($idLblGH, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idLblGH, $CLR_TXT_SECOND)
    GUICtrlSetBkColor($idLblGH, $CLR_BG_PRIMARY)

    $g_idLinkGitHub = GUICtrlCreateLabel("https://github.com/romoez/BacBackup", 250, 230, 320, 18, $SS_LEFT + $SS_NOTIFY)
    GUICtrlSetFont($g_idLinkGitHub, 9, 500, 4, $FONT_FAMILY) ; 4 = underline
    GUICtrlSetColor($g_idLinkGitHub, $CLR_ACCENT_INFO)
    GUICtrlSetBkColor($g_idLinkGitHub, $CLR_BG_PRIMARY)
    GUICtrlSetCursor($g_idLinkGitHub, 0)

    Local $idLblMail = GUICtrlCreateLabel("Contact :", 30, 258, 220, 18)
    GUICtrlSetFont($idLblMail, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idLblMail, $CLR_TXT_SECOND)
    GUICtrlSetBkColor($idLblMail, $CLR_BG_PRIMARY)

    $g_idLinkMail = GUICtrlCreateLabel("moez.romdhane@tarbia.tn", 250, 258, 320, 18, $SS_LEFT + $SS_NOTIFY)
    GUICtrlSetFont($g_idLinkMail, 9, 500, 4, $FONT_FAMILY)
    GUICtrlSetColor($g_idLinkMail, $CLR_ACCENT_INFO)
    GUICtrlSetBkColor($g_idLinkMail, $CLR_BG_PRIMARY)
    GUICtrlSetCursor($g_idLinkMail, 0)

    ; Pied : système hôte
    Local $aMois[13] = ["", "Janvier", "Février", "Mars", "Avril", "Mai", "Juin", _
            "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
    Local $iMonth = Number(@MON)
    Local $sMon = ($iMonth >= 1 And $iMonth <= 12) ? $aMois[$iMonth] : @MON

    Local $idHost = GUICtrlCreateLabel( _
            "Système : Windows " & StringTrimLeft(@OSVersion, 4) & " " & (@OSArch = "X86" ? "32-bit" : "64-bit") & _
            "  ·  " & @MDAY & " " & $sMon & " " & @YEAR, _
            30, $iH - 40, $iW - 60, 18)
    GUICtrlSetFont($idHost, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idHost, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idHost, $CLR_BG_PRIMARY)

    GUISwitch($g_hMainGUI)
    Return $hPanel
EndFunc   ;==>_BuildPanel_About


Func _BuildSettingRow($iY, $sLabel, $sIniKey, $sDefault, $sRange, $iIndex)
    Local $idLabel = GUICtrlCreateLabel($sLabel, 18, $iY + 4, 320, 18)
    GUICtrlSetFont($idLabel, 9, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idLabel, $CLR_TXT_PRIMARY)
    GUICtrlSetBkColor($idLabel, $CLR_BG_PRIMARY)

    Local $sValue = IniRead($g_sIniFile, "Params", $sIniKey, $sDefault)
    ; ES_NUMBER bloque toute touche non numérique au niveau du contrôle Edit
    Local $idInput = GUICtrlCreateInput($sValue, 350, $iY, 100, 26, $ES_NUMBER)
    GUICtrlSetFont($idInput, 9, 400, 0, $FONT_FAMILY)

    Local $idRange = GUICtrlCreateLabel("(" & $sRange & ")", 460, $iY + 4, 100, 18)
    GUICtrlSetFont($idRange, 8, 400, 0, $FONT_FAMILY)
    GUICtrlSetColor($idRange, $CLR_TXT_TERTIARY)
    GUICtrlSetBkColor($idRange, $CLR_BG_PRIMARY)

    Switch $iIndex
        Case 0
            $g_idInputIntervalSauve = $idInput
        Case 1
            $g_idInputIntervalCapt = $idInput
        Case 2
            $g_idInputTailleMax = $idInput
        Case 3
            $g_idInputNombreMax = $idInput
    EndSwitch
EndFunc   ;==>_BuildSettingRow


Func _SaveSettings()
    Local $aValues[4][3] = [ _
            [GUICtrlRead($g_idInputIntervalSauve), 1, 15], _
            [GUICtrlRead($g_idInputIntervalCapt),  2, 20], _
            [GUICtrlRead($g_idInputTailleMax),    10, 200], _
            [GUICtrlRead($g_idInputNombreMax),    20, 500] _
    ]
    Local $aKeys[4] = [ _
            "IntervalleInterSauvegardesEnMinutes", _
            "IntervalleInterCapturesEnSecondes", _
            "TailleMaxDuDossierBacBackupEnGigaoctet", _
            "NombreMaxDeDossiersDeSauve" _
    ]

    For $i = 0 To 3
        Local $iVal = Number($aValues[$i][0])
        If $iVal < $aValues[$i][1] Or $iVal > $aValues[$i][2] Then
            MsgBox(48, "Valeur invalide", "La valeur saisie pour """ & $aKeys[$i] & """ est hors plage." & @CRLF _
                    & "Plage autorisée : " & $aValues[$i][1] & " à " & $aValues[$i][2], 0, $g_hMainGUI)
            Return
        EndIf
    Next

    For $i = 0 To 3
        IniWrite($g_sIniFile, "Params", $aKeys[$i], $aValues[$i][0])
    Next

    MsgBox(64, "Enregistré", "Les paramètres ont été sauvegardés." & @CRLF & _
            "Ils prendront effet à la prochaine session de surveillance.", 0, $g_hMainGUI)
EndFunc   ;==>_SaveSettings


; -----------------------------------------------------------------------------
; _ResetSettings : restaure les valeurs par défaut dans les champs
; (sans enregistrer — l'utilisateur doit cliquer "Enregistrer" pour valider)
; -----------------------------------------------------------------------------
Func _ResetSettings()
    Local $iRep = MsgBox(BitOR(36, 262144), "Restaurer les valeurs par défaut", _
            "Restaurer les paramètres aux valeurs par défaut ?" & @CRLF & @CRLF & _
            "  • Intervalle inter-sauvegardes : 2 minutes" & @CRLF & _
            "  • Intervalle inter-captures : 5 secondes" & @CRLF & _
            "  • Taille maximale du dossier : 50 Go" & @CRLF & _
            "  • Nombre maximal de sessions : 100" & @CRLF & @CRLF & _
            "Cliquez ensuite sur ""Enregistrer"" pour appliquer.", _
            0, $g_hMainGUI)
    If $iRep <> 6 Then Return ; 6 = Oui ; toute autre réponse → annulé

    GUICtrlSetData($g_idInputIntervalSauve, "2")
    GUICtrlSetData($g_idInputIntervalCapt,  "5")
    GUICtrlSetData($g_idInputTailleMax,    "50")
    GUICtrlSetData($g_idInputNombreMax,   "100")
EndFunc   ;==>_ResetSettings


; =============================================================================
; ROUTAGE D'ONGLETS
; =============================================================================
Func _SwitchTab($iIndex)
    ; Cacher tous les panels
    For $i = 0 To UBound($g_aPanels) - 1
        If $g_aPanels[$i] Then GUISetState(@SW_HIDE, $g_aPanels[$i])
    Next

    ; Réinitialiser les couleurs des items de sidebar
    For $i = 0 To 6
        GUICtrlSetBkColor($g_aSidebarLinks[$i], $CLR_BG_PRIMARY)
        GUICtrlSetColor($g_aSidebarLinks[$i], $CLR_TXT_SECOND)
        GUICtrlSetFont($g_aSidebarLinks[$i], 9, 400, 0, $FONT_FAMILY)
    Next

    ; Mettre en évidence l'item actif
    GUICtrlSetBkColor($g_aSidebarLinks[$iIndex], $CLR_BG_SECONDARY)
    GUICtrlSetColor($g_aSidebarLinks[$iIndex], $CLR_TXT_PRIMARY)
    GUICtrlSetFont($g_aSidebarLinks[$iIndex], 9, 600, 0, $FONT_FAMILY)

    ; Afficher le panel cible
    GUISetState(@SW_SHOW, $g_aPanels[$iIndex])
    $g_iCurrentTab = $iIndex
    $g_hCurrentPanel = $g_aPanels[$iIndex]

    ; Refresh immédiat du nouvel onglet (sauf à la première construction
    ; où le panel est encore vide, géré par le _RefreshCurrentPanel idempotent)
    _RefreshCurrentPanel()
EndFunc   ;==>_SwitchTab


; =============================================================================
; HELPERS — État des composants & métriques
; =============================================================================
Func _CheckWatchdog()
    ; 1 = OK, 2 = warning, 3 = error
    ; Test direct par le processus : pas besoin de privilèges SCM.
    ; Le PB watchdog s'enregistre comme service "BBMonSvc" mais l'exécutable
    ; visible dans ProcessExists est "BacBackup_Watchdog.exe".
    If ProcessExists("BacBackup_Watchdog.exe") Then Return 1
    Return 3
EndFunc   ;==>_CheckWatchdog

Func _GetWatchdogPID()
    Local $iPID = ProcessExists("BacBackup_Watchdog.exe")
    If $iPID = 0 Then Return ""
    Return "PID " & $iPID
EndFunc   ;==>_GetWatchdogPID

Func _CheckClipboardListener()
    If ProcessExists("BacBackup.exe") Then Return 1
    Return 3
EndFunc   ;==>_CheckClipboardListener

Func _CountClipboardEntries()
    Local $sLog = $g_sCheminSauve & "\" & $g_sDossierSession & "\_journal_presse_papier.log"
    If Not FileExists($sLog) Then Return ""
    Local $sContent = FileRead($sLog)
    Local $aMatches = StringRegExp($sContent, "Type:\s+\w+", 3)
    If Not IsArray($aMatches) Then Return ""
    Return UBound($aMatches) & " entrées"
EndFunc   ;==>_CountClipboardEntries

Func _CheckUSBMonitoring()
    If ProcessExists("BacBackup.exe") Then Return 1
    Return 3
EndFunc   ;==>_CheckUSBMonitoring

Func _CountUSBAlerts()
    Local $sUSBDir = $g_sCheminSauve & "\" & $g_sDossierSession & "\_UsbWatcher"
    If Not FileExists($sUSBDir) Then Return "0 alerte"
    Local $aDirs = _FileListToArray($sUSBDir, "*", 2, False)
    If Not IsArray($aDirs) Then Return "0 alerte"
    Return $aDirs[0] & " alerte" & ($aDirs[0] > 1 ? "s" : "")
EndFunc   ;==>_CountUSBAlerts

Func _CheckACLLock()
    Local $sLockMarker = $g_sCheminSauve & "\.locked"
    If FileExists($sLockMarker) Then Return 1
    Return 2 ; warning : pas de marqueur trouvé
EndFunc   ;==>_CheckACLLock


Func _RefreshDashboardMetrics()
    ; ─── Captures ───
    Local $sCapDir = $g_sCheminSauve & "\" & $g_sDossierSession & "\_CapturesEcran"
    Local $iCaptures = 0
    If FileExists($sCapDir) Then
        Local $aCap = _FileListToArray($sCapDir, "*.png", 1, False)
        If IsArray($aCap) Then $iCaptures = $aCap[0]
    EndIf
    GUICtrlSetData($g_idMetric_Captures, $iCaptures)

    ; ─── Sessions ───
    Local $aSessions = _FileListToArray($g_sCheminSauve, "*", 2, False)
    Local $iNbSessions = (IsArray($aSessions) ? $aSessions[0] : 0)
    Local $iMax = Number(IniRead($g_sIniFile, "Params", "NombreMaxDeDossiersDeSauve", "100"))
    GUICtrlSetData($g_idMetric_Sessions, $iNbSessions & " / " & $iMax)

    ; ─── Espace libre ───
    Local $sDrive = StringLeft($g_sCheminSauve, 2)
    Local $iFreeMB = DriveSpaceFree($sDrive & "\")
    GUICtrlSetData($g_idMetric_FreeSpace, _FineSize($iFreeMB * 1024 * 1024))

    ; ─── Prochaine sauvegarde (estimation) ───
    Local $iIntervalMin = Number(IniRead($g_sIniFile, "Params", "IntervalleInterSauvegardesEnMinutes", "2"))
    GUICtrlSetData($g_idMetric_NextSave, "≤ " & $iIntervalMin & " min")
EndFunc   ;==>_RefreshDashboardMetrics


; -----------------------------------------------------------------------------
; Lecture du journal du presse-papier (lecture seule)
; -----------------------------------------------------------------------------
Func _RemplirJournalClipboard()
    If $g_idEditClipboard = 0 Then Return
    Local $sLogFile = $g_sCheminSauve & "\" & $g_sDossierSession & "\_journal_presse_papier.log"
    If FileExists($sLogFile) Then
        GUICtrlSetData($g_idEditClipboard, FileRead($sLogFile))
        ; Cache : timestamp de modif pour éviter relectures inutiles
        Local $aTime = FileGetTime($sLogFile, $FT_MODIFIED, 1)
        $g_iCacheClipboardMtime = (IsArray($aTime) ? Number($aTime) : Int($aTime))
    Else
        GUICtrlSetData($g_idEditClipboard, "(Aucun journal disponible pour cette session)")
        $g_iCacheClipboardMtime = 0
    EndIf
EndFunc   ;==>_RemplirJournalClipboard


; -----------------------------------------------------------------------------
; Refresh "live" intelligent : ne re-construit la liste que si quelque chose
; a changé sur le disque. Économise le CPU sur les disques chargés.
; -----------------------------------------------------------------------------

; Onglet 1 (Dossiers surveillés) :
; Comme le contenu est dérivé de la config (DossiersTravailEleves, Bureau,
; EasyPHP), il bouge rarement. On rafraîchit quand même si la "signature"
; change. Pour aller au plus simple, on compare juste le nombre d'éléments.
Func _RefreshPanelDossiers()
    If $g_idListeFichiers = 0 Then Return
    ; Construire la signature (comme dans _RemplirListeDossiers mais sans GUI)
    Local $aListe[1] = [0]
    Local $aTmp
    $aTmp = _DossiersTravailEleves()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)
    $aTmp = _DossiersSurBureau()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)
    $aTmp = DossiersEasyPHPwww()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)
    $aTmp = DossiersEasyPHPdata()
    If IsArray($aTmp) Then _AppendArray($aListe, $aTmp)

    ; Signature = nombre + concat des chemins (rapide)
    Local $sStamp = $aListe[0] & "|"
    For $i = 1 To $aListe[0]
        $sStamp &= $aListe[$i] & ";"
    Next

    If $sStamp = $g_iCacheDossiersStamp Then Return
    $g_iCacheDossiersStamp = $sStamp
    _RemplirListeDossiers()
EndFunc   ;==>_RefreshPanelDossiers


; Onglet 3 (USB) : on rafraîchit si le compte de dossiers a changé
Func _RefreshPanelUSB()
    If $g_idListeUSB = 0 Then Return
    Local $sUSBDir = $g_sCheminSauve & "\" & $g_sDossierSession & "\_UsbWatcher"
    Local $iCount = 0
    If FileExists($sUSBDir) Then
        Local $aDirs = _FileListToArray($sUSBDir, "*", 2, False)
        If IsArray($aDirs) Then $iCount = $aDirs[0]
    EndIf
    If $iCount = $g_iCacheUSBCount Then Return
    _RemplirListeUSB($g_idListeUSB)
EndFunc   ;==>_RefreshPanelUSB


; Onglet 4 (Presse-papier) : on rafraîchit si la mtime du fichier a changé
Func _RefreshPanelClipboard()
    If $g_idEditClipboard = 0 Then Return
    Local $sLogFile = $g_sCheminSauve & "\" & $g_sDossierSession & "\_journal_presse_papier.log"
    If Not FileExists($sLogFile) Then
        If $g_iCacheClipboardMtime <> 0 Then _RemplirJournalClipboard()
        Return
    EndIf
    Local $aTime = FileGetTime($sLogFile, $FT_MODIFIED, 1)
    Local $iMtime = (IsArray($aTime) ? Number($aTime) : Int($aTime))
    If $iMtime = $g_iCacheClipboardMtime Then Return
    _RemplirJournalClipboard()
EndFunc   ;==>_RefreshPanelClipboard


; Dispatcher : appelle le bon refresh selon l'onglet actif
Func _RefreshCurrentPanel()
    Switch $g_iCurrentTab
        Case 0
            _RefreshDashboardMetrics()
        Case 1
            _RefreshPanelDossiers()
        ; Onglet 2 (Sessions) : PAS de refresh automatique
        ;   - DirGetSize sur N sessions est coûteux
        ;   - Réécrirait le contenu toutes les 3s, ce qui re-déclenche le tri
        ;     en boucle (alternance asc/desc). Refresh manuel uniquement.
        Case 3
            _RefreshPanelUSB()
        Case 4
            _RefreshPanelClipboard()
        ; Onglets 5 (Paramètres) et 6 (À propos) : pas de refresh nécessaire
    EndSwitch
EndFunc   ;==>_RefreshCurrentPanel


; =============================================================================
; BOUCLE PRINCIPALE
; =============================================================================
Func _MainLoop()
    Local $iLastRefresh = TimerInit()

    While 1
        Local $aMsg = GUIGetMsg(1)
        Local $iEvent = $aMsg[0]
        Local $hWindow = $aMsg[1]

        ; ─── Fermeture de la fenêtre principale ───
        If $hWindow = $g_hMainGUI And $iEvent = $GUI_EVENT_CLOSE Then ExitLoop

        ; ─── Sidebar (sur la fenêtre principale uniquement) ───
        If $hWindow = $g_hMainGUI Then
            Switch $iEvent
                Case $g_aSidebarLinks[0]
                    _SwitchTab(0)
                    ContinueLoop
                Case $g_aSidebarLinks[1]
                    _SwitchTab(1)
                    ContinueLoop
                Case $g_aSidebarLinks[2]
                    _SwitchTab(2)
                    ContinueLoop
                Case $g_aSidebarLinks[3]
                    _SwitchTab(3)
                    ContinueLoop
                Case $g_aSidebarLinks[4]
                    _SwitchTab(4)
                    ContinueLoop
                Case $g_aSidebarLinks[5]
                    _SwitchTab(5)
                    ContinueLoop
                Case $g_aSidebarLinks[6]
                    _SwitchTab(6)
                    ContinueLoop
                Case $g_idFooterPath
                    _OpenSessionFolder()
                    ContinueLoop
            EndSwitch
        EndIf

        ; ─── Boutons d'action du dashboard (panel enfant) ───
        ; Les contrôles créés dans un panel enfant n'apparaissent dans GUIGetMsg
        ; qu'avec leur ID — la fenêtre rapportée peut être le panel.
        ; On compare donc directement l'ID indépendamment de $hWindow.
        Switch $iEvent
            Case $g_idBtnForcedBackup
                _ActionForcedBackup()
            Case $g_idBtnOpenSession, $g_idSessionPath
                _OpenSessionFolder()
            Case $g_idBtnSaveSettings
                _SaveSettings()
            Case $g_idBtnResetSettings
                _ResetSettings()
            Case $g_idLinkGitHub
                ShellExecute("https://github.com/romoez/BacBackup", "", "", "open")
            Case $g_idLinkMail
                ShellExecute("mailto:moez.romdhane@tarbia.tn?subject=BacBackup " & $g_sProgVersion)
        EndSwitch

        ; ─── Refresh automatique de l'onglet actif toutes les 3 s ───
        If TimerDiff($iLastRefresh) > 3000 Then
            _RefreshCurrentPanel()
            $iLastRefresh = TimerInit()
        EndIf

        Sleep(20)
    WEnd
EndFunc   ;==>_MainLoop


; =============================================================================
; ACTIONS DES BOUTONS DU DASHBOARD
; =============================================================================

Func _OpenSessionFolder()
    Local $sPath = $g_sCheminSauve & "\" & $g_sDossierSession
    If FileExists($sPath) Then
        Run("explorer.exe /e, " & '"' & $sPath & '"')
    ElseIf FileExists($g_sCheminSauve) Then
        Run("explorer.exe /e, " & '"' & $g_sCheminSauve & '"')
    Else
        MsgBox(48, "Dossier introuvable", _
                "Le dossier de session est introuvable :" & @CRLF & @CRLF & $sPath, 0, $g_hMainGUI)
    EndIf
EndFunc   ;==>_OpenSessionFolder


Func _ActionForcedBackup()
    ; Lance le module Sauvegarder en mode 'forcee'
    Local $sExe = @ScriptDir & "\BacBackup_Sauvegarder.exe"
    If Not FileExists($sExe) Then
        MsgBox(48, "Module manquant", "BacBackup_Sauvegarder.exe est introuvable.", 0, $g_hMainGUI)
        Return
    EndIf
    Local $sSession = $g_sCheminSauve & "\" & $g_sDossierSession
    ShellExecute($sExe, 'forcee "' & $sSession & '"')
    ; Feedback visuel (toast très simple)
    ToolTip("Sauvegarde forcée déclenchée", -1, -1, "BacBackup", 1, 4)
    Sleep(2000)
    ToolTip("")
EndFunc   ;==>_ActionForcedBackup


; =============================================================================
; HANDLER WM_NOTIFY (double-clic sur ListView Dossiers et Sessions)
; =============================================================================
Func _WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
    #forceref $iMsg, $wParam
    Local $tNMHDR = DllStructCreate("int;int;int", $lParam)
    Local $iCode = DllStructGetData($tNMHDR, 3)

    ; ─── Double-clic sur ListView "Dossiers surveillés" ───
    If $wParam = $g_idListeFichiers And $iCode = $NM_DBLCLK Then
        Local $aSel = _GUICtrlListView_GetSelectedIndices($g_idListeFichiers, True)
        If $aSel[0] > 0 Then
            Local $sPath = _GUICtrlListView_GetItemText($g_idListeFichiers, $aSel[1], 1)
            _ShowInExplorer($sPath)
        EndIf
    EndIf

    ; ─── Double-clic sur ListView "Sessions" ───
    If $wParam = $g_idListeSessions And $iCode = $NM_DBLCLK Then
        Local $aSel = _GUICtrlListView_GetSelectedIndices($g_idListeSessions, True)
        If $aSel[0] > 0 Then
            ; Colonnes : 0=Lecteur (ex "C:") 1=Session (ex "001___...")
            Local $sDrive   = _GUICtrlListView_GetItemText($g_idListeSessions, $aSel[1], 0)
            Local $sSession = _GUICtrlListView_GetItemText($g_idListeSessions, $aSel[1], 1)
            Local $sFullPath = $sDrive & "\Sauvegardes\BacBackup\" & $sSession
            _ShowInExplorer($sFullPath)
        EndIf
    EndIf

    ; ─── Clic sur entête de ListView "Sessions" → tri ───
    If $wParam = $g_idListeSessions And $iCode = $LVN_COLUMNCLICK Then
        ; La structure NMLISTVIEW contient iSubItem à l'offset 12 octets
        ; après le NMHDR (qui fait 12 octets = 3*int sur x86 ou 24 sur x64).
        ; On utilise une struct AutoIt qui matche $tagNMLISTVIEW.
        Local $tNMLV = DllStructCreate($tagNMLISTVIEW, $lParam)
        Local $iCol = DllStructGetData($tNMLV, "SubItem")
        _TriListeSessions($iCol)
    EndIf

    Return $GUI_RUNDEFMSG
EndFunc   ;==>_WM_NOTIFY


Func _ShowInExplorer($sPath)
    If Not FileExists($sPath) Then
        MsgBox(48, "Élément introuvable", "Cet élément a été déplacé ou supprimé :" & @CRLF & @CRLF & $sPath, 0, $g_hMainGUI)
        Return
    EndIf
    If FileGetAttrib($sPath) = "D" Then
        Run("explorer.exe /n, /e, " & '"' & $sPath & '"')
    Else
        Run("explorer.exe /n, /e, /select, " & '"' & $sPath & '"')
    EndIf
EndFunc   ;==>_ShowInExplorer

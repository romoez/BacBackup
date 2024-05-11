#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_Compression=4
;~ #AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Run_Au3Stripper=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#pragma compile(Icon, BacBackup.ico)
#pragma compile(FileDescription, BacBackup Auto-Sauvegarde)
#pragma compile(FileVersion, 2.2.7.511, 2.2.7.511) ; Le dernier paramètre est optionnel
#pragma compile(ProductName, BacBackup)
#pragma compile(ProductVersion, 2.2.7.511)

#pragma compile(LegalCopyright, 2016-2024 © La Communauté Tunisienne des Enseignants d'Informatique)
#pragma compile(Comments,'BacBackup - Module du Premier Démarrage')
#pragma compile(Out, Installer\Files\BacBackup_PremierDemarrage.exe)
#pragma compile(CompanyName, La Communauté Tunisienne des Enseignants d'Informatique)
#NoTrayIcon

#include "include\Toast.au3"  ; https://www.autoitscript.com/forum/topic/108445-how-to-make-toast-new-version-2-aug-18/

ShellExecute(@ScriptDir & "\BacBackup_Sauvegarder.exe")
$Msg = "BacBackup surveille désormais les dossiers de travail" & @CRLF & " des élèves." & @CRLF
$Msg &= "♣ ♣ ♣ ♣ ♣ ♣ ♣ ♣ ♣ ♣" & @CRLF & @CRLF & "♥ ♥ ♥ Raccourcis Clavier ♥ ♥ ♥" & @CRLF
$Msg &= "↓  ↓  ↓  ↓  ↓  ↓  ↓" & @CRLF & @CRLF
$Msg &= "Ctrl+Shift+Win+F5 ►► Prend une Sauvegarde à l'instant.  " & @CRLF
$Msg &= "Ctrl+Shift+Win+F6 ►► Affiche l'Interface de l'Application."
;$Msg&="Ctrl+Shift+F7 ►► Ouvre le Dossier de Sauvegarde.   "

_Toast_Set(5, 0xFF4500, 0x1C1C1C, 0x1C1C1C, 0xFF4500, 12, "Tahoma")
$aRet = _Toast_Show("res\Logo01.png", "BacBackup", $Msg, -40)
ConsoleWrite("Toast size: " & $aRet[0] & " x " & $aRet[1] & @CRLF)
_Toast_Hide()
Exit
;☺☻♥♦♣♠•◘○○◙♂♀♪♪♫☼►↑♫§¶►◄↕‼¶§▬↨↑↓→←∟↔▲▼ !"#$%&'()*+,-

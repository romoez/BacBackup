; Programme de déprotection de fichier Security.ini
; Utilise icacls et vérification par mot de passe avec élévation automatique
EnableExplicit
UseMD5Fingerprint()

; Hash MD5 du mot de passe correct
#HASH_MDP_CORRECT = "516623ABD538987FAE1E72A38452C908"
#FICHIER_CIBLE = "Security.ini"

; Procédure pour vérifier si le programme tourne avec des droits administrateur
Procedure EstAdministrateur()
  Protected resultat, programme
  
  programme = RunProgram("cmd.exe", "/c net session >nul 2>&1", "", #PB_Program_Hide | #PB_Program_Open)
  
  If programme
    ; Attendre la fin du programme
    WaitProgram(programme)
    resultat = ProgramExitCode(programme)
    CloseProgram(programme)
    
    If resultat = 0
      ProcedureReturn #True
    EndIf
  EndIf
  
  ProcedureReturn #False
EndProcedure

; Procédure pour relancer le programme en tant qu'administrateur
Procedure RelancerEnAdministrateur()
  Protected executable$
  
  executable$ = ProgramFilename()
  
  ; Utilise ShellExecute avec "runas" pour demander l'élévation
  RunProgram("powershell.exe", 
             "-Command Start-Process '" + executable$ + "' -Verb RunAs", 
             "", #PB_Program_Hide)
  
  End
EndProcedure

; Procédure pour débloquer le fichier avec icacls
Procedure DebloquerFichier()
  Protected commande$, programme, codeRetour
  
  ; Vérification que le fichier existe
  If FileSize(#FICHIER_CIBLE) = -1
    MessageRequester("Erreur", 
                     "Le fichier '" + #FICHIER_CIBLE + "' est introuvable." + #CRLF$ +
                     "Assurez-vous que le fichier se trouve dans le même répertoire que ce programme.", 
                     #PB_MessageRequester_Error)
    ProcedureReturn #False
  EndIf
  
  ; Commande pour retirer toutes les permissions héritées et restrictions
  commande$ = "icacls " + Chr(34) + #FICHIER_CIBLE + Chr(34) + " /reset"
  
  programme = RunProgram("cmd.exe", "/c " + commande$, "", #PB_Program_Hide | #PB_Program_Open)
  
  If programme
    ; Attendre la fin de l'exécution
    WaitProgram(programme)
    codeRetour = ProgramExitCode(programme)
    CloseProgram(programme)
    
    If codeRetour = 0
      ; Succès
      MessageRequester("Succès", 
                       "Le fichier '" + #FICHIER_CIBLE + "' a été déprotégé avec succès !", 
                       #PB_MessageRequester_Info)
      ProcedureReturn #True
    Else
      ; Échec
      MessageRequester("Erreur", 
                       "La commande icacls a échoué (code : " + Str(codeRetour) + ")." + #CRLF$ + #CRLF$ +
                       "Causes possibles :" + #CRLF$ +
                       "• Le fichier est actuellement utilisé par un autre programme" + #CRLF$ +
                       "• Droits administrateur insuffisants" + #CRLF$ +
                       "• Le système de fichiers ne supporte pas les ACL", 
                       #PB_MessageRequester_Error)
      ProcedureReturn #False
    EndIf
  Else
    MessageRequester("Erreur", 
                     "Impossible d'exécuter la commande icacls." + #CRLF$ +
                     "Vérifiez que cmd.exe est accessible.", 
                     #PB_MessageRequester_Error)
    ProcedureReturn #False
  EndIf
EndProcedure

; === POINT D'ENTRÉE PRINCIPAL ===

; Vérification des droits administrateur
If Not EstAdministrateur()
  If MessageRequester("Droits administrateur requis", 
                      "Ce programme nécessite des droits administrateur pour déprotéger le fichier '" + #FICHIER_CIBLE + "'." + #CRLF$ + #CRLF$ +
                      "Voulez-vous relancer le programme en tant qu'administrateur ?", 
                      #PB_MessageRequester_Warning | #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes
    RelancerEnAdministrateur()
  Else
    MessageRequester("Information", "Le programme va se fermer.", #PB_MessageRequester_Info)
  EndIf
  End
EndIf

; === Interface utilisateur ===
OpenWindow(0, 0, 0, 380, 200, "Déprotection de " + #FICHIER_CIBLE, #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
TextGadget(1, 20, 20, 340, 20, "Mot de passe de secours :")
StringGadget(2, 20, 50, 340, 25, "", #PB_String_Password)
ButtonGadget(3, 20, 100, 340, 35, "Déprotéger le fichier")
TextGadget(4, 20, 150, 340, 30, "En attente du mot de passe...", #PB_Text_Center)

; Variables
Define motdepasse$, hashCalcule$

Repeat
  Select WaitWindowEvent()
    Case #PB_Event_CloseWindow
      Break
      
    Case #PB_Event_Gadget
      If EventGadget() = 3
        motdepasse$ = GetGadgetText(2)
        
        ; Vérification que le champ n'est pas vide
        If Len(motdepasse$) = 0
          SetGadgetText(4, "⚠ Veuillez entrer un mot de passe")
          Continue
        EndIf
        
        ; Calcul et vérification du hash MD5
        hashCalcule$ = UCase(StringFingerprint(motdepasse$, #PB_Cipher_MD5))
        
        If hashCalcule$ = #HASH_MDP_CORRECT
          SetGadgetText(4, "✓ Mot de passe correct ! Déprotection en cours...")
          
          ; Débloque le fichier
          If DebloquerFichier()
            SetGadgetText(4, "✓ Opération terminée avec succès !")
            DisableGadget(3, #True)
            DisableGadget(2, #True)
          Else
            SetGadgetText(4, "✗ Échec de la déprotection")
            SetGadgetText(2, "")
          EndIf
        Else
          SetGadgetText(4, "✗ Mot de passe incorrect !")
          SetGadgetText(2, "")
        EndIf
      EndIf
  EndSelect
ForEver
; IDE Options = PureBasic 6.21 (Windows - x86)
; CursorPosition = 110
; FirstLine = 82
; Folding = -
; Optimizer
; EnableXP
; EnableAdmin
; UseIcon = res\Unlock_Sec.ico
; Executable = Installer\Files\Unlock_Sec.exe
; IncludeVersionInfo
; VersionField0 = 1.0.0.0
; VersionField1 = 2.5.26.218
; VersionField2 = Communauté Tunisienne des Enseignants d'Informatique
; VersionField3 = BacBackup
; VersionField4 = 2.5.26
; VersionField5 = 1.0
; VersionField6 = Dé-protège le fichier Security.ini de BacBackup
; VersionField7 = Unlock_Sec
; VersionField8 = Unlock_Sec
; VersionField9 = © 2016-2026 Communauté Tunisienne des Enseignants d'Informatique
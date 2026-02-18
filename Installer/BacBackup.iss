#define MyAppName "BacBackup"
#define MyAppVersion GetVersionNumbersString('Files\BacBackup.exe')
#define MyAppPublisher "Communauté Tunisienne des Enseignants d'Informatique"
#define MyAppPublisherURL "https://github.com/romoez/BacBackup"
#define MyAppURL "https://github.com/romoez/BacBackup"
#define MyAppUpdateURL "https://github.com/romoez/BacBackup"
#define MyAppContact "moez.romdhane@tarbia.tn"
#define MyAppComment "BacBackup|Capture en temps réel de l'activité des élèves et sauvegarde automatique de leurs travaux"


[Setup]
AppId={{498AA8A4-2CBE-4368-BFA0-E0CF3F338536}
AllowNoIcons=yes
AppComments={#MyAppComment}
AppContact={#MyAppContact}
AppCopyright={#MyAppPublisher}
AppName={#MyAppName}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppUpdateURL}
;AppVerName={#MyAppName}
AppVersion={#MyAppVersion}
ChangesAssociations=yes
CloseApplications=no
Compression=lzma2/ultra64
DefaultDirName={commonpf}\BacBackup
DefaultGroupName={#MyAppName}
DisableDirPage=yes
DisableFinishedPage=no
DisableProgramGroupPage=yes
DisableReadyMemo=no
FlatComponentsList=false
InternalCompressLevel=ultra
OutputBaseFilename={#MyAppName}-{#MyAppVersion}-Setup
PrivilegesRequired=admin
ShowLanguageDialog=no
SolidCompression=yes
UninstallDisplayIcon={app}\BacBackup.exe,0
UninstallDisplayName={#MyAppName}
VersionInfoCompany={#MyAppPublisher}
VersionInfoVersion={#MyAppVersion}
WizardImageStretch=yes
WizardStyle=modern dynamic

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
; Name: "en"; MessagesFile: "compiler:Default.isl"

[Files]
Source: Files\*; DestDir: {app}; Flags: ignoreversion recursesubdirs createallsubdirs

[Run]
; Filename: {app}\BacBackup.EXE; Description: "Lancer BacBackup"; Flags: nowait postinstall;

[Registry]
Root: HKA; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "BacBackup"; ValueData: """{app}\BacBackup.exe"""; Flags: uninsdeletevalue
Root: HKCU; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"; ValueType: dword; ValueName: "NoSecurityTab"; ValueData: "1"; Flags: uninsdeletevalue

[UninstallDelete]
; Type: files; Name: "{localappdata}\BacBackup\*.*"; 
; Type: filesandordirs; Name: "{localappdata}\BacBackup"; 
Type: filesandordirs; Name: "{app}\*"; 
Type: filesandordirs; Name: "{app}\*.*"; 
Type: dirifempty; Name: "{app}"; 

[UninstallRun]
Filename: {sys}\taskkill.exe; Parameters: "/f /im BacBackup.exe"; Flags: skipifdoesntexist runhidden; RunOnceId: "KillBacBackup"

[Code]

// ============================================================================
// VARIABLES GLOBALES
// ============================================================================
var
  PasswordPage: TInputQueryWizardPage;
  PasswordEdit: TPasswordEdit;
  ConfirmEdit: TPasswordEdit;
  AdminPassword: String;
  IsUpdate: Boolean;

// ============================================================================
// CONSTANTES
// ============================================================================
const
  DRIVE_UNKNOWN = 0;
  DRIVE_NO_ROOT_DIR = 1;
  DRIVE_REMOVABLE = 2;
  DRIVE_FIXED = 3;
  DRIVE_REMOTE = 4;
  DRIVE_CDROM = 5;
  DRIVE_RAMDISK = 6;
  
  // Mot de passe de secours (hash MD5)
  BACKUP_PASSWORD_HASH = '516623ABD538987FAE1E72A38452C908';

// ============================================================================
// DÉCLARATIONS EXTERNES
// ============================================================================
function GetDriveType(lpRootPathName: String): UINT;
  external 'GetDriveTypeW@kernel32.dll stdcall';

// ============================================================================
// Vérifie si un lecteur est un disque fixe
// ============================================================================
function IsFixedDrive(Drive: String): Boolean;
begin
  if Copy(Drive, Length(Drive), 1) <> '\' then
    Drive := Drive + '\';
  Result := GetDriveType(Drive) = DRIVE_FIXED;
end;

// ============================================================================
// Valide le format du mot de passe (longueur et absence d'espaces)
// ============================================================================
function ValidatePassword(const Password: String; var ErrorMsg: String): Boolean;
begin
  Result := False;
  
  // Vérifier la longueur minimale
  if Length(Password) < 4 then
  begin
    ErrorMsg := 'Le mot de passe doit contenir au moins 4 caractères.';
    Exit;
  end;
  
  // Vérifier l'absence d'espaces
  if Pos(' ', Password) > 0 then
  begin
    ErrorMsg := 'Le mot de passe ne doit pas contenir d''espaces.';
    Exit;
  end;
  
  Result := True;
end;

// ============================================================================
// Lit le hash du mot de passe depuis Security.ini
// Retourne une chaîne vide si le fichier n'existe pas ou si le hash est vide
// ============================================================================
function GetStoredPasswordHash: String;
var
  SecurityFile: String;
begin
  SecurityFile := ExpandConstant('{app}\Security.ini');
  
  if FileExists(SecurityFile) then
  begin
    Result := GetIniString('Security', 'PasswordHash', '', SecurityFile);
  end
  else
  begin
    Result := '';
  end;
end;

// ============================================================================
// Vérifie le mot de passe lors de la désinstallation
// Utilise le mot de passe de secours si Security.ini est absent ou vide
// ============================================================================
function VerifyUninstallPassword: Boolean;
var
  StoredHash: String;
  InputPassword: String;
  InputHash: String;
  Attempts: Integer;
  PasswordForm: TSetupForm;
  PasswordLabel: TLabel;
  PasswordEdit: TPasswordEdit;
  OKButton, CancelButton: TNewButton;
  ModalResult: Integer;
begin
  Result := False;
  Attempts := 0;
  
  // Récupérer le hash stocké
  StoredHash := GetStoredPasswordHash;
  
  // Si le fichier n'existe pas ou le hash est vide, utiliser le mot de passe de secours
  if StoredHash = '' then
  begin
    Log('Security.ini absent ou vide - Utilisation du mot de passe de secours');
    StoredHash := BACKUP_PASSWORD_HASH;
  end;
  
  // Demander le mot de passe (maximum 3 tentatives)
  while (Attempts < 3) and (not Result) do
  begin
    // Créer le formulaire
    PasswordForm := CreateCustomForm(ScaleX(400), ScaleY(150), False, False);
    try
      PasswordForm.Caption := 'Désinstallation de BacBackup';
      PasswordForm.Position := poScreenCenter;
      
      // Label
      PasswordLabel := TLabel.Create(PasswordForm);
      PasswordLabel.Parent := PasswordForm;
      PasswordLabel.Left := ScaleX(20);
      PasswordLabel.Top := ScaleY(20);
      PasswordLabel.Width := ScaleX(360);
      PasswordLabel.Height := ScaleY(40);
      PasswordLabel.AutoSize := False;
      PasswordLabel.WordWrap := True;
      PasswordLabel.Caption := 'Veuillez entrer le mot de passe de protection :' + #13#10 + 
                               'Tentative ' + IntToStr(Attempts + 1) + ' sur 3';
      
      // Champ mot de passe
      PasswordEdit := TPasswordEdit.Create(PasswordForm);
      PasswordEdit.Parent := PasswordForm;
      PasswordEdit.Left := ScaleX(20);
      PasswordEdit.Top := ScaleY(65);
      PasswordEdit.Width := ScaleX(360);
      PasswordEdit.Height := ScaleY(23);
      
      // Bouton OK
      OKButton := TNewButton.Create(PasswordForm);
      OKButton.Parent := PasswordForm;
      OKButton.Caption := 'OK';
      OKButton.Left := ScaleX(220);
      OKButton.Top := ScaleY(105);
      OKButton.Width := ScaleX(75);
      OKButton.Height := ScaleY(25);
      OKButton.ModalResult := mrOk;
      OKButton.Default := True;
      
      // Bouton Annuler
      CancelButton := TNewButton.Create(PasswordForm);
      CancelButton.Parent := PasswordForm;
      CancelButton.Caption := 'Annuler';
      CancelButton.Left := ScaleX(305);
      CancelButton.Top := ScaleY(105);
      CancelButton.Width := ScaleX(75);
      CancelButton.Height := ScaleY(25);
      CancelButton.ModalResult := mrCancel;
      CancelButton.Cancel := True;
      
      // Afficher le formulaire
      ModalResult := PasswordForm.ShowModal;
      
      if ModalResult = mrOk then
      begin
        InputPassword := PasswordEdit.Text;
        
        // Calculer le hash du mot de passe saisi
        InputHash := GetMD5OfString(InputPassword);
        
        // Comparer les hashs
        if CompareText(InputHash, StoredHash) = 0 then
        begin
          Result := True;
          Log('Mot de passe correct - Désinstallation autorisée');
        end
        else
        begin
          Attempts := Attempts + 1;
          if Attempts < 3 then
            MsgBox('Mot de passe incorrect. Veuillez réessayer.', mbError, MB_OK)
          else
            MsgBox('Mot de passe incorrect. Désinstallation annulée.', mbError, MB_OK);
        end;
      end
      else
      begin
        // L'utilisateur a annulé
        Log('Désinstallation annulée par l''utilisateur');
        Exit;
      end;
    finally
      PasswordForm.Free;
    end;
  end;
end;

// ============================================================================
// Protection anti-suppression de BacBackup
// ============================================================================
procedure ProtegerFichiersExecution;
var
  AppPath: String;
  ResultCode: Integer;
  Fichiers: TArrayOfString;
  I: Integer;
  CmdLine: String;
  SuccessCount: Integer;
begin
  AppPath := ExpandConstant('{app}');
  Log('=== Début protection BacBackup ===');
  SuccessCount := 0;

  // 1. Bloquer la suppression via le dossier parent (CRUCIAL)
  CmdLine := Format('icacls.exe "%s" /deny *S-1-1-0:(DC) /C', [AppPath]);
  if Exec(ExpandConstant('{sys}\icacls.exe'), 
          Format('"%s" /deny *S-1-1-0:(DC) /C', [AppPath]),
          '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('✓ Protection du dossier parent appliquée')
    else
      Log(Format('⚠ Protection du dossier parent avec code: %d', [ResultCode]));
  end
  else
    Log('✗ Échec de la protection du dossier parent');

  // 2. Liste STRICTE des fichiers à protéger
  SetArrayLength(Fichiers, 8);
  Fichiers[0] := 'BacBackup.exe';
  Fichiers[1] := 'BacBackup_Interface.exe';
  Fichiers[2] := 'BacBackup_Sauvegarder.exe';
  Fichiers[3] := 'BacBackup_Watchdog.exe';
  Fichiers[4] := '7za.exe';
  Fichiers[5] := 'Security.ini';
  Fichiers[6] := 'Unlock_Sec.exe';
  Fichiers[7] := 'BacBackup_UsbWatcher.exe';

  // 3. Protection fichier par fichier
  for I := 0 to GetArrayLength(Fichiers) - 1 do
  begin
    if FileExists(AppPath + '\' + Fichiers[I]) then
    begin
      // Interdire suppression + écriture
      if Exec(ExpandConstant('{sys}\icacls.exe'),
              Format('"%s\%s" /deny *S-1-1-0:(DE,WD,WA) /C', [AppPath, Fichiers[I]]),
              '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      begin
        if ResultCode = 0 then
        begin
          SuccessCount := SuccessCount + 1;
          Log(Format('✓ Protégé: %s', [Fichiers[I]]));
        end
        else
          Log(Format('⚠ Protection partielle: %s (code %d)', [Fichiers[I], ResultCode]));
      end
      else
        Log(Format('✗ Échec protection: %s', [Fichiers[I]]));
    end
    else
      Log(Format('🛑 Fichier absent (non protégé): %s', [Fichiers[I]]));
  end;

  Log(Format('=== Protection terminée: %d/%d fichiers protégés ===', [SuccessCount, GetArrayLength(Fichiers)]));
end;

// ============================================================================
// Déprotection complète AVANT désinstallation ou mise à jour
// ============================================================================
procedure DeprotegerFichiers;
var
  AppPath: String;
  ResultCode: Integer;
begin
  AppPath := ExpandConstant('{app}');
  Log('=== Début déprotection BacBackup ===');
  
  // Vérifier que le dossier existe
  if not DirExists(AppPath) then
  begin
    Log('🛑 Dossier application inexistant - Rien à déprotéger');
    Exit;
  end;
  
  // Réinitialiser les permissions avec /reset
  // /reset : Restaure les permissions par défaut
  // /T : Récursif (tous les sous-dossiers et fichiers)
  // /c : Continue malgré les erreurs
  if Exec(ExpandConstant('{sys}\icacls.exe'),
          Format('"%s" /reset /T /c', [AppPath]),
          '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('✓ Permissions réinitialisées avec succès')
    else
      Log(Format('⚠ Permissions réinitialisées avec avertissements (code %d)', [ResultCode]));
  end
  else
    Log('✗ Échec de la réinitialisation des permissions');
  
  Log('=== Déprotection terminée ===');
end;

// ========================================================================
// Débloquer les dossiers "Sauvegardes" sur tous les lecteurs fixes
// ========================================================================

// Procédure utilitaire pour débloquer UN dossier spécifique sans toucher au contenu

procedure UnlockSpecificFolder(const Path: String);
var
  ResultCode: Integer;
begin
  if DirExists(Path) then
  begin
    Log('🔓 Déblocage ciblé : ' + Path);
    // On réinitialise les ACL uniquement sur le dossier (pas de /T ici)
    Exec(ExpandConstant('{sys}\icacls.exe'), '"' + Path + '" /reset /c /q', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // On retire le "Lecture seule", "Système" et "Caché" sur le dossier lui-même
    Exec(ExpandConstant('{sys}\attrib.exe'), '-r -s -h "' + Path + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure UnlockDossiersSauvegardes;
var
  I, Pourcentage: Integer;
  Drive, Root: String;
begin
  Log('→ Déblocage des dossiers "Sauvegardes"...');
  Pourcentage := 5; 
  // Message initial de patience
  UninstallProgressForm.StatusLabel.Caption := 'Initialisation du déblocage des dossiers... Veuillez patienter.';
  UninstallProgressForm.ProgressBar.Position := Pourcentage;

  for I := Ord('C') to Ord('Z') do
  begin
    Drive := Chr(I) + ':\';
    if GetDriveType(Drive) <> DRIVE_FIXED then Continue;
    if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
    UninstallProgressForm.ProgressBar.Position := Pourcentage;

    Root := Drive + 'Sauvegardes';
    if not DirExists(Root) then Continue;

    // --- Mise à jour de l'interface par disque ---
    if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
    UninstallProgressForm.ProgressBar.Position := Pourcentage;
    UninstallProgressForm.StatusLabel.Caption := 'Analyse du disque ' + Drive + '... Veuillez patienter.';

    // 1. Déblocage des droits (icacls / attrib)
    if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
    UninstallProgressForm.ProgressBar.Position := Pourcentage;
    UninstallProgressForm.StatusLabel.Caption := 'Restauration des droits d''accès sur ' + Root + '... Veuillez patienter.';
    
    // On débloque les 3 points clés (Racine, BacBackup, BacCollector)
    UnlockSpecificFolder(Root);
    if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
    UninstallProgressForm.ProgressBar.Position := Pourcentage;
    UninstallProgressForm.StatusLabel.Caption := 'Restauration des droits d''accès sur ' + Root + '\BacBackup' + '... Veuillez patienter.';
    UnlockSpecificFolder(Root + '\BacBackup');
    if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
    UninstallProgressForm.ProgressBar.Position := Pourcentage;
    UninstallProgressForm.StatusLabel.Caption := 'Restauration des droits d''accès sur ' + Root + '\BacCollector' + '... Veuillez patienter.';
    UnlockSpecificFolder(Root + '\BacCollector');

    // 2. Nettoyage des fichiers de verrouillage
    if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
    UninstallProgressForm.ProgressBar.Position := Pourcentage;
    UninstallProgressForm.StatusLabel.Caption := 'Suppression des fichiers de configuration et verrous...';

    DeleteFile(Root + '\.locked');
    DeleteFile(Root + '\BacBackup\BacBackup.ini');
    DeleteFile(Root + '\BacBackup\.locked');
    DeleteFile(Root + '\BacCollector\.locked');

    // 3. Suppression du dossier temporaire
    if DirExists(Root + '\Tmp') then
    begin
      if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
      UninstallProgressForm.ProgressBar.Position := Pourcentage;
      UninstallProgressForm.StatusLabel.Caption := 'Nettoyage du dossier temporaire (' + Root + '\Tmp)...';
      DelTree(Root + '\Tmp', True, True, True);
    end;

    Log('✨ Nettoyage terminé pour ' + Drive);
  end;

  // Message final avant de passer à l'étape suivante
  if Pourcentage < 90 then Pourcentage := Pourcentage + 10;
  UninstallProgressForm.ProgressBar.Position := Pourcentage;
  UninstallProgressForm.StatusLabel.Caption := 'Déblocage et nettoyage terminés.';
end;

procedure UnlockDossiersSauvegardes___;
var
  I: Integer;
  Drive, SauveFolderPath, BacBackupFolderPath, BacCollectorFolderPath: String;
  ResultCode: Integer;
begin
  Log('→ Déblocage des dossiers "Sauvegardes" (méthode cohérente avec BacBackup)...');

  for I := Ord('C') to Ord('Z') do
  begin
    Drive := Chr(I) + ':\';
    if GetDriveType(Drive) <> DRIVE_FIXED then
      Continue;

    SauveFolderPath := Drive + 'Sauvegardes';
    if not DirExists(SauveFolderPath) then
      Continue;
  
    Log(Format('🔍 Traitement : %s', [SauveFolderPath]));
    BacBackupFolderPath := SauveFolderPath + '\BacBackup'
    BacCollectorFolderPath := SauveFolderPath + '\BacCollector'
    // 🔓 ÉTAPE 1 : Réinitialiser les ACL (équivalent à _UnlockFolder AutoIt)
    if Exec(ExpandConstant('{sys}\icacls.exe'),
            '"' + SauveFolderPath + '" /reset /c /q',
            '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      case ResultCode of
        0:     Log(Format('✅ ACL réinitialisées : %s', [SauveFolderPath]));
        5:     Log(Format('❌ Accès refusé (exécuter setup en admin) : %s', [SauveFolderPath]));
      else
        Log(Format('⚠ icacls /reset code %d sur %s', [ResultCode, SauveFolderPath]));
      end;
    end
    else
      Log(Format('⚠ Échec exécution icacls sur %s', [SauveFolderPath]));

    if Exec(ExpandConstant('{sys}\icacls.exe'),
            '"' + BacBackupFolderPath + '" /reset /c /q',
            '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      case ResultCode of
        0:     Log(Format('✅ ACL réinitialisées : %s', [BacBackupFolderPath]));
        5:     Log(Format('❌ Accès refusé (exécuter setup en admin) : %s', [BacBackupFolderPath]));
      else
        Log(Format('⚠ icacls /reset code %d sur %s', [ResultCode, BacBackupFolderPath]));
      end;
    end
    else
      Log(Format('⚠ Échec exécution icacls sur %s', [BacBackupFolderPath]));


    if Exec(ExpandConstant('{sys}\icacls.exe'),
            '"' + BacCollectorFolderPath + '" /reset /c /q',
            '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      case ResultCode of
        0:     Log(Format('✅ ACL réinitialisées : %s', [BacCollectorFolderPath]));
        5:     Log(Format('❌ Accès refusé (exécuter setup en admin) : %s', [BacCollectorFolderPath]));
      else
        Log(Format('⚠ icacls /reset code %d sur %s', [ResultCode, BacCollectorFolderPath]));
      end;
    end
    else
      Log(Format('⚠ Échec exécution icacls sur %s', [BacCollectorFolderPath]));

    // 👁 ÉTAPE 2 : Retirer attributs Système + Caché
    if Exec(ExpandConstant('{sys}\attrib.exe'),
            '-s -h "' + SauveFolderPath + '"',
            '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if ResultCode = 0 then
        Log(Format('👁 Attributs -S -H retirés : %s', [SauveFolderPath]))
      else
        Log(Format('⚠ attrib -s -h échoué (code %d) sur %s', [ResultCode, SauveFolderPath]));
    end;

    // 🧹 ÉTAPE 3 : Nettoyage
    if DirExists(SauveFolderPath + '\Tmp') then
    begin
      if DelTree(SauveFolderPath + '\Tmp', True, True, True) then
        Log(Format('🗑 Dossier Tmp supprimé : %s\Tmp', [SauveFolderPath]))
      else
        Log(Format('⚠ Échec suppression Tmp : %s\Tmp', [SauveFolderPath]));
    end;

    if FileExists(SauveFolderPath + '\BacBackup\BacBackup.ini') then
    begin
      if DeleteFile(SauveFolderPath + '\BacBackup\BacBackup.ini') then
        Log('🗑 Fichier de config supprimé')
      else
        Log('⚠ Échec suppression BacBackup.ini');
    end;

    if FileExists(SauveFolderPath + '\.locked') then
    begin
      if DeleteFile(SauveFolderPath + '\.locked') then
        Log('🗑 Fichier .locked supprimé')
      else
        Log('⚠ Échec suppression .locked');
    end;

    if FileExists(SauveFolderPath + '\BacBackup\.locked') then
    begin
      if DeleteFile(SauveFolderPath + '\BacBackup\.locked') then
        Log('🗑 Fichier BacBackup\.locked supprimé')
      else
        Log('⚠ Échec suppression BacBackup\.locked');
    end;

    if FileExists(SauveFolderPath + '\BacCollector\.locked') then
    begin
      if DeleteFile(SauveFolderPath + '\BacCollector\.locked') then
        Log('🗑 Fichier BacCollector\.locked supprimé')
      else
        Log('⚠ Échec suppression BacCollector\.locked');
    end;
  end;

  Log('→ Déblocage terminé.');
end;

// ============================================================================
// Initialisation de l'assistant d'installation
// Crée la page de saisie du mot de passe
// ============================================================================
procedure InitializeWizard;
begin

  IsUpdate := RegKeyExists(HKEY_LOCAL_MACHINE,
      'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{498AA8A4-2CBE-4368-BFA0-E0CF3F338536}_is1') or 
               RegKeyExists(HKEY_CURRENT_USER,
      'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{498AA8A4-2CBE-4368-BFA0-E0CF3F338536}_is1');

      
  // Si le mot de passe est passé en paramètre (/password=1234 ou /p=1234
  AdminPassword := ExpandConstant('{param:PASSWORD|{param:P|}}');
  
  // if AdminPassword <> '' or WizardSilent or IsUpdate then Exit;
      
  if not WizardSilent and not IsUpdate and (AdminPassword = '') then
  begin
    // Créer une page personnalisée après la page de sélection du répertoire
    PasswordPage := CreateInputQueryPage(wpSelectDir,
      'Configuration de la sécurité BacBackup', 
      'Définition du mot de passe administrateur',
        ''#13#10'Ce mot de passe sera requis pour :'#13#10 +
        '    • Ouvrir l''interface de BacBackup,'#13#10 +
        '    • Désinstaller le logiciel.'#13#10#13#10);

    // Champ mot de passe
    PasswordPage.Add('Mot de passe administrateur (4 caractères min, sans espaces):', True);
    PasswordEdit := PasswordPage.Edits[0];

    // Champ confirmation
    PasswordPage.Add('Confirmez le mot de passe:', True);
    ConfirmEdit := PasswordPage.Edits[1];
  end;
end;

// ============================================================================
// Validation lors du clic sur le bouton Suivant
// Vérifie le mot de passe sur la page dédiée
// ============================================================================
function NextButtonClick(CurPageID: Integer): Boolean;
var
  ErrorMsg: String;
begin
  Result := True;

  if (AdminPassword <> '') or WizardSilent or IsUpdate then Exit;
       
  // Valider uniquement sur la page du mot de passe
  if CurPageID = PasswordPage.ID then
  begin
    // Valider le mot de passe
    if not ValidatePassword(PasswordEdit.Text, ErrorMsg) then
    begin
      MsgBox(ErrorMsg, mbError, MB_OK);
      Result := False;
      Exit;
    end;
    
    // Vérifier que les mots de passe correspondent
    if PasswordEdit.Text <> ConfirmEdit.Text then
    begin
      MsgBox('Les mots de passe ne correspondent pas. Veuillez réessayer.', mbError, MB_OK);
      Result := False;
      Exit;
    end;
    
    // Sauvegarder le mot de passe validé
    AdminPassword := PasswordEdit.Text;
  end;
end;

// ============================================================================
// Vérifie si un processus est en cours d'exécution
// ============================================================================

const
  TH32CS_SNAPPROCESS = $00000002;
  INVALID_HANDLE_VALUE = -1;

type
  TProcessEntry32 = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: UINT_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: Longint;
    dwFlags: DWORD;
    szExeFile: array[0..259] of Char; // MAX_PATH = 260
  end;

function CreateToolhelp32Snapshot(dwFlags, th32ProcessID: DWORD): THandle;
  external 'CreateToolhelp32Snapshot@kernel32.dll stdcall';

function Process32FirstW(hSnapshot: THandle; var lppe: TProcessEntry32): Boolean;
  external 'Process32FirstW@kernel32.dll stdcall';

function Process32NextW(hSnapshot: THandle; var lppe: TProcessEntry32): Boolean;
  external 'Process32NextW@kernel32.dll stdcall';

function CloseHandle(hObject: THandle): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';

// ============================================================================
// Vérifie si un processus est en cours d'exécution
// ============================================================================
function IsModuleLoaded(const Name: String): Boolean;
var
  Snapshot: THandle;
  Entry: TProcessEntry32;
  CurrentExeName: String;
  I: Integer;
begin
  Result := False;
  
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snapshot = INVALID_HANDLE_VALUE then 
    Exit;

  try
    Entry.dwSize := SizeOf(Entry);
    
    // On utilise Process32FirstW (la version Unicode)
    if Process32FirstW(Snapshot, Entry) then
    begin
      repeat
        // --- Conversion manuelle du tableau de Char en String ---
        CurrentExeName := '';
        for I := 0 to 259 do // MAX_PATH - 1
        begin
          // On s'arrête dès qu'on rencontre le caractère nul (fin de chaîne API)
          if Entry.szExeFile[I] = #0 then 
            Break;
          CurrentExeName := CurrentExeName + Entry.szExeFile[I];
        end;
        // -------------------------------------------------------

        if SameText(CurrentExeName, Name) then
        begin
          Result := True;
          Break;
        end;
      until not Process32NextW(Snapshot, Entry);
    end;
  finally
    CloseHandle(Snapshot);
  end;
end;

procedure ArretCompletBacBackup;
var
  ResultCode, Attempts: Integer;
begin
  Log('=== [ArretCompletBacBackup] Démarrage de la procédure d''arrêt global ===');

  // 1. On désactive le service pour éviter qu'il ne redémarre tout seul (Watchdog)
  if Exec('sc.exe', 'config BBMonSvc start= disabled', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('✅ Service désactivé (start=disabled)')
    else if ResultCode = 5 then
      Log(Format('⚠ Accès refusé lors de la désactivation du service (code %d)', [ResultCode]))
    else if ResultCode = 1060 then
      Log(Format('ℹ Service inexistant lors de la désactivation (code %d)', [ResultCode]))
    else
      Log(Format('⚠ Désactivation du service avec code %d', [ResultCode]));
  end
  else
    Log('❌ Échec de l''exécution "sc config BBMonSvc start= disabled"');

  if Exec('net.exe', 'stop BBMonSvc /y', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('✅ Service arrêté avec succès')
    else if ResultCode = 2 then
      Log(Format('ℹ Service déjà arrêté (code %d)', [ResultCode]))
    else if ResultCode = 5 then
      Log(Format('⚠ Accès refusé lors de l''arrêt du service (code %d)', [ResultCode]))
    else if ResultCode = 1060 then
      Log(Format('ℹ Service inexistant (code %d)', [ResultCode]))
    else
      Log(Format('⚠ Arrêt du service avec code %d', [ResultCode]));
  end
  else
    Log('❌ Échec de l''exécution "net stop BBMonSvc /y"');

  // 2. Kill forcé des processus (et leurs enfants avec /T)
  if Exec('taskkill.exe', '/f /im BacBackup_Watchdog.exe /t', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('✅ BacBackup_Watchdog.exe terminé')
    else if ResultCode = 128 then
      Log('ℹ BacBackup_Watchdog.exe déjà arrêté (code 128)')
    else
      Log(Format('⚠ taskkill BacBackup_Watchdog.exe code %d', [ResultCode]));
  end
  else
    Log('❌ Échec de l''exécution taskkill pour BacBackup_Watchdog.exe');

  if Exec('taskkill.exe', '/f /im BacBackup.exe /t', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    if ResultCode = 0 then
      Log('✅ BacBackup.exe terminé')
    else if ResultCode = 128 then
      Log('ℹ BacBackup.exe déjà arrêté (code 128)')
    else
      Log(Format('⚠ taskkill BacBackup.exe code %d', [ResultCode]));
  end
  else
    Log('❌ Échec de l''exécution taskkill pour BacBackup.exe');

  // 3. Attente active de libération des fichiers
  Attempts := 0;
  while (Attempts < 6) do
  begin
    if not IsModuleLoaded('BacBackup_Watchdog.exe') and not IsModuleLoaded('BacBackup.exe') then
    begin
      Log(Format('✅ Tous les processus libérés après %d seconde(s)', [Attempts]));
      Break;
    end;
    
    Log('...attente de libération des fichiers (tentative ' + IntToStr(Attempts+1) + '/6)...');
    Sleep(1000);
    Attempts := Attempts + 1;
  end;
  
  if Attempts = 6 then
    Log('⚠ Timeout atteint après 6 secondes - certains processus peuvent rester actifs');

  // 4. Déprotection des fichiers pour permettre l'écriture/suppression
  if DirExists(ExpandConstant('{app}')) then
  begin
    Log('🔓 Déprotection des fichiers...');
    DeprotegerFichiers;
    Log('✅ Déprotection terminée');
  end
  else
    Log('⏭ Dossier {app} inexistant - déprotection ignorée');

  Log('=== [ArretCompletBacBackup] Procédure terminée ===');
end;


// --- INSTALLATION ---
procedure CurStepChanged(CurStep: TSetupStep);
var
  SecurityFile, PasswordHash: String;
  ResultCode: Integer;
begin
  if CurStep = ssInstall then
  begin
    // Nettoyage agressif (Arrêt + Désactivation + Kill + Déprotection)
    ArretCompletBacBackup;
  end
  else if CurStep = ssPostInstall then
  begin
    Log('=== Post-installation ===');
    
    // ✅ 1. Gestion du Security.ini (votre logique conservée)
    PasswordHash := '';
    if AdminPassword <> '' then 
    begin
      PasswordHash := GetMD5OfString(AdminPassword);
      Log('✅ Mode normal ou silencieux avec mot de passe fourni');
    end
    else if WizardSilent and not IsUpdate then 
    begin
      PasswordHash := '4A7D1ED414474E4033AC29CCB8653D9B';
      Log('ℹ Mode silencieux sans mot de passe → Mot de passe par défaut(4x0)');
    end;
    
    if PasswordHash <> '' then
    begin
      SecurityFile := ExpandConstant('{app}\Security.ini');
      if SetIniString('Security', 'PasswordHash', PasswordHash, SecurityFile) then
        Log('✅ Security.ini mis à jour')
      else
        Log('❌ Échec écriture Security.ini');
    end;

    // ✅ 2. RÉACTIVATION DU SERVICE (Crucial pour sortir du mode 'disabled')
    // Note : Il faut un espace après "start=" -> "start= auto"
    Log('→ Réactivation du service (start= auto)...');
    Exec('sc.exe', 'config BBMonSvc start= auto', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

    // ✅ 3. Installation/Mise à jour du service
    Log('→ Enregistrement du service watchdog...');
    if Exec(ExpandConstant('{app}\BacBackup_Watchdog.exe'), '--install', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if ResultCode = 0 then Log('✅ Service installé/mis à jour')
      else Log(Format('⚠ --install a retourné le code %d', [ResultCode]));
    end;

    // ✅ 4. Démarrage du service
    Log('→ Démarrage du service...');
    if Exec('sc.exe', 'start BBMonSvc', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    begin
      if (ResultCode = 0) or (ResultCode = 1056) then
        Log('✅ Service opérationnel')
      else
        Log(Format('⚠ Échec démarrage (code %d). Vérifiez si le service est bien en mode auto.', [ResultCode]));
    end;

    // ✅ 5. Verrouillage final
    Log('→ Protection des fichiers...');
    ProtegerFichiersExecution;

    Log('=== Installation terminée ===');
  end;
end;

// ============================================================================
// Désactive l'option de lancement automatique sur la page finale
// ============================================================================
procedure CurPageChanged(CurPageID: Integer);
begin
  if (CurPageID = wpFinished) and (WizardForm.RunList.Items.Count > 0) then
  Begin
    WizardForm.RunList.ItemEnabled[0] := False;
  End;
end;

// ============================================================================
// Initialisation de la désinstallation
// Vérifie le mot de passe avant de permettre la désinstallation
// ============================================================================
function InitializeUninstall(): Boolean;
begin
  Result := VerifyUninstallPassword;
  
  if not Result then
  begin
    Log('Désinstallation bloquée - Mot de passe incorrect ou annulation');
  end;
end;

// ============================================================================
// Gestion des changements d'étape pendant la désinstallation
// ============================================================================
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    // On utilise la même fonction que pour l'install !
    ArretCompletBacBackup;
    
    // Suppression propre du service
    Log('→ Suppression du service...');
    Exec('sc.exe', 'delete BBMonSvc', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    // Déverrouiller les dossiers de sauvegarde
    UnlockDossiersSauvegardes;
  end
  else if CurUninstallStep = usPostUninstall then
  begin
    
    // Nettoyage final du dossier si nécessaire
    if DirExists(ExpandConstant('{app}')) then
       DelTree(ExpandConstant('{app}'), True, True, True);
  end;
end;

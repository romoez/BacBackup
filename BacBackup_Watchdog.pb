; =============================================================================
; BacBackup_Watchdog.pb — Service Windows (x86 / Unicode)
; - Surveillance & redémarrage automatique de BacBackup.exe
; - Service : BBMonSvc (LocalSystem)
; - Cible la session utilisateur active (WTS)
; - Journal : "C:\Sauvegardes\BacBackup\Journal_BB_Watchdog.log" (tronqué à 5 Mo)
; - Compatible Windows 7 → 11
; =============================================================================

EnableExplicit

CompilerIf #PB_Compiler_Unicode = #False
  CompilerError "Ce projet doit être compilé en mode Unicode."
CompilerEndIf

; --- Constantes ---
#TH32CS_SNAPPROCESS                = $2
#PROCESS_QUERY_LIMITED_INFORMATION = $1000

#SERVICE_NAME       = "BBMonSvc"
#DISPLAY_NAME       = "BacBackup Monitoring Service"
#RESTART_DELAY_MS   = 2500
#MAX_LOG_SIZE_BYTES = 5 * 1024 * 1024  ; 5 Mo

; --- Globales ---
Global g_AppDirectory.s
Global g_ExePath.s
Global g_LogFile.s
Global g_ServiceStopEvent.i = 0

; --- Forward Declarations ---
Declare.i StartBacBackupInSession(sessionId.l)
Declare ServiceHandler(dwControl.l)
Declare ServiceMain()
Declare _TruncateLogIfTooBig()
Declare AdjustPrivilege(token.i, privName.s)

; --- Structures ---
Structure UNICODE_BUFFER
  Data.w[1024]
EndStructure

Structure PROCESSENTRY32W
  dwSize.l
  cntUsage.l
  th32ProcessID.l
  th32DefaultHeapID.i
  th32ModuleID.l
  cntThreads.l
  th32ParentProcessID.l
  pcPriClassBase.l
  dwFlags.l
  szExeFile.w[260]
EndStructure

Structure WTS_SESSION_INFO
  SessionId.l
  pWinStationName.i
  State.l
EndStructure

Structure BB_TOKEN_PRIVILEGES
  PrivilegeCount.l
  LuidLowPart.l
  LuidHighPart.l
  Attributes.l
EndStructure

CompilerIf Defined(LUID, #PB_Structure) = #False
  Structure LUID
    LowPart.l
    HighPart.l
  EndStructure
CompilerEndIf

CompilerIf Defined(STARTUPINFO, #PB_Structure) = #False
  Structure STARTUPINFO
    cb.l
    lpReserved.l
    lpDesktop.l
    lpTitle.l
    dwX.l
    dwY.l
    dwXSize.l
    dwYSize.l
    dwXCountChars.l
    dwYCountChars.l
    dwFillAttribute.l
    dwFlags.l
    wShowWindow.w
    cbReserved2.w
    lpReserved2.l
    hStdInput.l
    hStdOutput.l
    hStdError.l
  EndStructure
CompilerEndIf

CompilerIf Defined(PROCESS_INFORMATION, #PB_Structure) = #False
  Structure PROCESS_INFORMATION
    hProcess.i
    hThread.i
    dwProcessId.l
    dwThreadId.l
  EndStructure
CompilerEndIf

; --- API Declarations ---
Import "kernel32.lib"
  GetCurrentProcess() As "_GetCurrentProcess@0"
  OpenProcess(dwDesiredAccess.l, bInheritHandle.l, dwProcessId.l) As "_OpenProcess@12"
  CloseHandle(hObject.i) As "_CloseHandle@4"
  CreateToolhelp32Snapshot(dwFlags.l, th32ProcessID.l) As "_CreateToolhelp32Snapshot@8"
  Process32FirstW(hSnapshot.i, lppe.i) As "_Process32FirstW@8"
  Process32NextW(hSnapshot.i, lppe.i) As "_Process32NextW@8"
  QueryFullProcessImageNameW(hProcess.i, dwFlags.l, lpExeName.i, lpdwSize.i) As "_QueryFullProcessImageNameW@16"
  CreateEventW(lpEventAttributes.i, bManualReset.l, bInitialState.l, lpName.i) As "_CreateEventW@16"
  SetEvent(hEvent.i) As "_SetEvent@4"
  WaitForSingleObject(hObject.i, dwMilliseconds.l) As "_WaitForSingleObject@8"
  GetModuleHandleW(lpModuleName.i) As "_GetModuleHandleW@4"
  GetModuleFileNameW(hModule.i, lpFilename.i, nSize.l) As "_GetModuleFileNameW@12"
  GetLastError() As "_GetLastError@0"
EndImport

Import "advapi32.lib"
  OpenSCManagerW(lpMachineName.i, lpDatabaseName.i, dwDesiredAccess.l) As "_OpenSCManagerW@12"
  CloseServiceHandle(hSCManager.i) As "_CloseServiceHandle@4"
  CreateServiceW(hSCManager.i, lpServiceName.i, lpDisplayName.i, dwDesiredAccess.l, dwServiceType.l, dwStartType.l, dwErrorControl.l, lpBinaryPathName.i, lpLoadOrderGroup.i, lpTagId.i, lpDependencies.i, lpServiceStartName.i, lpPassword.i) As "_CreateServiceW@52"
  OpenServiceW(hSCManager.i, lpServiceName.i, dwDesiredAccess.l) As "_OpenServiceW@12"
  StartServiceW(hService.i, dwNumServiceArgs.l, lpServiceArgVectors.i) As "_StartServiceW@12"
  QueryServiceStatus(hService.i, lpServiceStatus.i) As "_QueryServiceStatus@8"
  ChangeServiceConfig2W(hService.i, dwInfoLevel.l, lpInfo.i) As "_ChangeServiceConfig2W@12"
  DuplicateTokenEx(hExistingToken.i, dwDesiredAccess.l, lpTokenAttributes.i, ImpersonationLevel.l, TokenType.l, phNewToken.i) As "_DuplicateTokenEx@24"
  AdjustTokenPrivileges(hToken.i, DisableAllPrivileges.l, NewState.i, BufferLength.l, PreviousState.i, ReturnLength.i) As "_AdjustTokenPrivileges@24"
  LookupPrivilegeValueW(lpSystemName.i, lpName.i, lpLuid.i) As "_LookupPrivilegeValueW@12"
  StartServiceCtrlDispatcherW(lpServiceTable.i) As "_StartServiceCtrlDispatcherW@4"
EndImport

Import "wtsapi32.lib"
  WTSEnumerateSessionsW(hServer.i, Reserved.l, Version.l, *ppSessionInfo, *pCount) As "_WTSEnumerateSessionsW@20"
  WTSFreeMemory(*pMemory) As "_WTSFreeMemory@4"
  WTSQueryUserToken(SessionId.l, *phToken) As "_WTSQueryUserToken@8"
  WTSGetActiveConsoleSessionId() As "_WTSGetActiveConsoleSessionId@0"
EndImport

Import "advapi32.lib"
  CreateProcessAsUserW(hToken.i, lpApplicationName.i, lpCommandLine.i, lpProcessAttributes.i, lpThreadAttributes.i, bInheritHandles.l, dwCreationFlags.l, lpEnvironment.i, lpCurrentDirectory.i, lpStartupInfo.i, lpProcessInformation.i) As "_CreateProcessAsUserW@44"
EndImport

; =============================================================================
; UTILITAIRES
; =============================================================================
Procedure InitializePaths()
  Protected buffer.UNICODE_BUFFER
  Protected size.l = GetModuleFileNameW(GetModuleHandleW(#Null), @buffer\Data, 1024)
  
  If size > 0
    Protected fullPath.s = PeekS(@buffer\Data, size, #PB_Unicode)
    g_AppDirectory = GetPathPart(fullPath)
    If Right(g_AppDirectory, 1) = "\"
      g_AppDirectory = Left(g_AppDirectory, Len(g_AppDirectory) - 1)
    EndIf
  Else
    g_AppDirectory = "C:\Program Files (x86)\BacBackup"
  EndIf
  
  g_ExePath = g_AppDirectory + "\BacBackup.exe"
;   g_LogFile = g_AppDirectory + "\journal_watcher.log"
  g_LogFile = "C:\Sauvegardes\BacBackup\Journal_BB_Watchdog.log"
EndProcedure

Procedure _Log(message.s)
  _TruncateLogIfTooBig() ; ✅ vérif préalable à chaque écriture

  Protected hFile.i
  Protected timestamp.s = FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date())
  Protected logLine.s = timestamp + " | " + message

  Protected dir.s = GetPathPart(g_LogFile)
  If dir <> "" And Not FileSize(dir) = -2
    CreateDirectory(dir)
  EndIf

  hFile = OpenFile(#PB_Any, g_LogFile, #PB_File_Append)
  If hFile
    WriteStringN(hFile, logLine)
    CloseFile(hFile)
  EndIf
  ; Silencieux en cas d'échec — pas de popup, pas de blocage
EndProcedure


Procedure _TruncateLogIfTooBig()
  Protected size.l = FileSize(g_LogFile)
  If size <= #MAX_LOG_SIZE_BYTES
    ProcedureReturn
  EndIf

  Dim lines.s(0)
  Protected countLines.l = 0
  Protected maxLines.l = 120  ; nombre max de lignes conservées
  Protected hFile.i, line.s, i.l 

  ; Lire les dernières lignes avec buffer circulaire
  hFile = ReadFile(#PB_Any, g_LogFile)
  If hFile
    While Eof(hFile) = 0
      line = ReadString(hFile)
      lines(countLines % maxLines) = line
      countLines + 1
    Wend
    CloseFile(hFile)
  EndIf

  ; ✂️ Réécrire uniquement les dernières lignes (dans l'ordre)
  hFile = CreateFile(#PB_Any, g_LogFile)
  If hFile
    Protected start.l = 0, total.l = countLines
    If countLines > maxLines
      start = countLines % maxLines
      total = maxLines
    EndIf

    For i = 0 To total - 1
      Protected idx.l = (start + i) % maxLines
      WriteStringN(hFile, lines(idx))
    Next

    CloseFile(hFile)
    _Log("♻ Log tronqué à " + Str(total) + " lignes (anciennement " + Str(size / 1024) + " Ko)")
  EndIf
EndProcedure

; =============================================================================
; FONCTIONS BAS NIVEAU
; =============================================================================
Procedure.i ProcessExists(exeName.s, fullPath.s = "")
  Protected hSnap.i = CreateToolhelp32Snapshot(#TH32CS_SNAPPROCESS, 0)
  If hSnap = -1 : ProcedureReturn #False : EndIf

  Protected pe.PROCESSENTRY32W
  pe\dwSize = SizeOf(PROCESSENTRY32W)

  If Process32FirstW(hSnap, @pe)
    Repeat
      Protected currentName.s = PeekS(@pe\szExeFile, -1, #PB_Unicode)
      If LCase(currentName) = LCase(exeName)
        If fullPath = ""
          CloseHandle(hSnap)
          ProcedureReturn #True
        Else
          Protected hProc.i = OpenProcess(#PROCESS_QUERY_LIMITED_INFORMATION, #False, pe\th32ProcessID)
          If hProc
            Protected buffer.UNICODE_BUFFER
            Protected size.l = 1024
            If QueryFullProcessImageNameW(hProc, 0, @buffer\Data, @size)
              Protected imagePath.s = PeekS(@buffer\Data, size, #PB_Unicode)
              If LCase(imagePath) = LCase(fullPath)
                CloseHandle(hProc)
                CloseHandle(hSnap)
                ProcedureReturn #True
              EndIf
            EndIf
            CloseHandle(hProc)
          EndIf
        EndIf
      EndIf
    Until Not Process32NextW(hSnap, @pe)
  EndIf
  CloseHandle(hSnap)
  ProcedureReturn #False
EndProcedure

Procedure.l FindActiveSessionId()
  Protected *pSessionList, count.l, i.l, sessionId.l = -1
  Protected info.WTS_SESSION_INFO

  If WTSEnumerateSessionsW(0, 0, 1, @*pSessionList, @count)
    For i = 0 To count - 1
      CopyMemory(*pSessionList + i * SizeOf(WTS_SESSION_INFO), @info, SizeOf(WTS_SESSION_INFO))
      If info\State = 0 ; WTSActive
        sessionId = info\SessionId
        Break
      EndIf
    Next
    WTSFreeMemory(*pSessionList)
  EndIf

  If sessionId = -1
    sessionId = WTSGetActiveConsoleSessionId()
  EndIf
  ProcedureReturn sessionId
EndProcedure

Procedure AdjustPrivilege(token.i, privName.s)
  Protected luid.LUID
  Protected tp.BB_TOKEN_PRIVILEGES
  
  If LookupPrivilegeValueW(#Null, @privName, @luid)
    tp\PrivilegeCount = 1
    tp\LuidLowPart = luid\LowPart
    tp\LuidHighPart = luid\HighPart
    tp\Attributes = $2 ; SE_PRIVILEGE_ENABLED
    AdjustTokenPrivileges(token, #False, @tp, SizeOf(BB_TOKEN_PRIVILEGES), #Null, #Null)
  EndIf
EndProcedure


; =============================================================================
; FONCTIONS SERVICE
; =============================================================================
Procedure.i StartBacBackupInSession(sessionId.l)
  If FileSize(g_ExePath) < 0
    _Log("❌ BacBackup.exe introuvable : " + g_ExePath)
    ProcedureReturn #False
  EndIf

  Protected hUserToken.i, hDupToken.i
  If Not WTSQueryUserToken(sessionId, @hUserToken)
    _Log("❌ WTSQueryUserToken échoué (session " + Str(sessionId) + ") - Erreur: " + Str(GetLastError()))
    ProcedureReturn #False
  EndIf

  If Not DuplicateTokenEx(hUserToken, $F01FF, #Null, 2, 1, @hDupToken)
    CloseHandle(hUserToken)
    _Log("❌ DuplicateTokenEx échoué - Erreur: " + Str(GetLastError()))
    ProcedureReturn #False
  EndIf
  CloseHandle(hUserToken)

  AdjustPrivilege(hDupToken, "SeAssignPrimaryTokenPrivilege")
  AdjustPrivilege(hDupToken, "SeIncreaseQuotaPrivilege")

  Protected si.STARTUPINFO, pi.PROCESS_INFORMATION
  ZeroMemory_(@si, SizeOf(STARTUPINFO))
  si\cb = SizeOf(STARTUPINFO)
  si\dwFlags = $1 ; STARTF_USESHOWWINDOW
  si\wShowWindow = 0 ; SW_HIDE

  Protected cmdLine.s = Chr(34) + g_ExePath + Chr(34)

  If CreateProcessAsUserW(hDupToken, #Null, @cmdLine, #Null, #Null, #False,
                          $08000000, ; CREATE_NO_WINDOW
                          #Null, @g_AppDirectory, @si, @pi)
    CloseHandle(pi\hProcess)
    CloseHandle(pi\hThread)
    CloseHandle(hDupToken)
    _Log("✅ BacBackup relancé dans session " + Str(sessionId) + " (PID: " + Str(pi\dwProcessId) + ")")
    ProcedureReturn #True
  EndIf

  Protected lastError.l = GetLastError()
  CloseHandle(hDupToken)
  _Log("❌ CreateProcessAsUser échoué - Erreur: " + Str(lastError))
  ProcedureReturn #False
EndProcedure

Procedure ServiceHandler(dwControl.l)
  Select dwControl
    Case $1, $5 ; SERVICE_CONTROL_STOP, SERVICE_CONTROL_SHUTDOWN
      If g_ServiceStopEvent
        SetEvent(g_ServiceStopEvent)
      EndIf
  EndSelect
EndProcedure

Procedure ServiceMain()
  g_ServiceStopEvent = CreateEventW(#Null, #True, #False, #Null)
  If g_ServiceStopEvent = 0
    ; Échec critique — on sort
    _Log("❌ Impossible de créer l'événement d'arrêt")
    End
  EndIf

  _Log("✅ Service " + #SERVICE_NAME + " démarré")
  _Log("✅ Surveillance : " + g_ExePath)

  Protected sessionId.l, checkCount.l = 0

  Repeat
    Sleep_(#RESTART_DELAY_MS)
    checkCount + 1

    ; Rapport de santé tous les ~10 min (240 * 2,5 s ≈ 10 min)
    If checkCount % 240 = 0
      _Log("✅ Service actif (vérification #" + Str(checkCount) + ")")
    EndIf

    sessionId = FindActiveSessionId()
    If sessionId = -1
      Continue ; Aucune session → attendre
    EndIf

    If Not ProcessExists("BacBackup.exe", g_ExePath)
      _Log("⚠ BacBackup absent → tentative de relance...")
      StartBacBackupInSession(sessionId)
      ; Pas de vérif immédiate post-relance (le prochain cycle le fera)
    EndIf

  ForEver ; Terminé via ServiceHandler → événement

  _Log("⏹ Service arrêté proprement")
  If g_ServiceStopEvent
    CloseHandle(g_ServiceStopEvent)
    g_ServiceStopEvent = 0
  EndIf
  ; Le service se termine après le ForEver
EndProcedure

; =============================================================================
; GESTION DU SERVICE
; =============================================================================
Procedure.i InstallService()
  Protected hSCM.i = OpenSCManagerW(#Null, #Null, $2)
  If Not hSCM
    _Log("❌ Impossible d'ouvrir le SCM - Erreur: " + Str(GetLastError()))
    ProcedureReturn #False
  EndIf

  Protected buffer.UNICODE_BUFFER
  Protected size.l = GetModuleFileNameW(GetModuleHandleW(#Null), @buffer\Data, 1024)
  If size = 0
    CloseServiceHandle(hSCM)
    _Log("❌ Impossible d'obtenir le chemin du watcher")
    ProcedureReturn #False
  EndIf

  Protected exePath.s = PeekS(@buffer\Data, size, #PB_Unicode)
  Protected binPath.s = Chr(34) + exePath + Chr(34)

  Protected serviceName.s = #SERVICE_NAME
  Protected displayName.s = #DISPLAY_NAME

  Protected hSvc.i = CreateServiceW(hSCM, @serviceName, @displayName,
                                     $F01FF, $10, $2, $1,
                                     @binPath, #Null, #Null, #Null, #Null, #Null)

  If hSvc
    ; Configurer les redémarrages automatiques en cas d'échec
    Structure SC_ACTION
      Type.l
      Delay.l
    EndStructure
    Structure SERVICE_FAILURE_ACTIONS
      dwResetPeriod.l
      lpRebootMsg.i
      lpCommand.i
      cActions.l
      lpsaActions.i
    EndStructure

    Protected Dim actions.SC_ACTION(2)
    actions(0)\Type = 1 : actions(0)\Delay = 3000   ; restart in 3s
    actions(1)\Type = 1 : actions(1)\Delay = 5000   ; then 5s
    actions(2)\Type = 1 : actions(2)\Delay = 10000  ; then 10s

    Protected failureActions.SERVICE_FAILURE_ACTIONS
    failureActions\dwResetPeriod = 86400 ; 24h
    failureActions\cActions = 3
    failureActions\lpsaActions = @actions()

    ChangeServiceConfig2W(hSvc, 2, @failureActions) ; ignorer échec ici

    CloseServiceHandle(hSvc)
    CloseServiceHandle(hSCM)
    _Log("✅ Service installé")
    ProcedureReturn #True
  Else
    Protected err = GetLastError()
    CloseServiceHandle(hSCM)
    If err = 1073
      _Log("ℹ Service déjà installé")
    Else
      _Log("❌ Échec installation service - Erreur: " + Str(err))
    EndIf
    ProcedureReturn #False
  EndIf
EndProcedure

Procedure DebugMode()
  _Log("🐛 Mode DEBUG (boucle infinie, pas de relance)")

  Protected check.l = 0
  Repeat
    Sleep_(3000)
    check + 1
    If ProcessExists("BacBackup.exe", g_ExePath)
      _Log("✓ " + Str(check) + " : BacBackup actif")
    Else
      _Log("⚠ " + Str(check) + " : BacBackup absent (pas de relance en debug)")
    EndIf
  ForEver
EndProcedure

Procedure InstallMode()
  _Log("🔧 Installation du service...")
  InstallService()
EndProcedure

Procedure ServiceMode()
  _Log("✅ Démarrage du service...")

  Protected serviceNameW.s = #SERVICE_NAME
  Protected Dim serviceTable.SERVICE_TABLE_ENTRY(1)
  serviceTable(0)\lpServiceName = @serviceNameW
  serviceTable(0)\lpServiceProc = @ServiceMain()
  serviceTable(1)\lpServiceName = #Null
  serviceTable(1)\lpServiceProc = #Null

  If Not StartServiceCtrlDispatcherW(@serviceTable(0))
    Protected err = GetLastError()
    _Log("❌ Échec démarrage service (code " + Str(err) + ")")
    If err = 1063
      _Log("ℹ Ce binaire doit être lancé par SCM (ex: 'net start BBMonSvc')")
    EndIf
  EndIf
EndProcedure

; =============================================================================
; POINT D'ENTRÉE
; =============================================================================
InitializePaths()

Select LCase(ProgramParameter())
  Case "--install", "/install"
    InstallMode()
    End
  
  Case "--debug", "/debug"
    DebugMode()

  Default
    ServiceMode()
EndSelect
; IDE Options = PureBasic 6.21 (Windows - x86)
; CursorPosition = 500
; FirstLine = 487
; Folding = ---
; EnableThread
; EnableXP
; Executable = Installer\Files\BacBackup_Watchdog.exe
; IncludeVersionInfo
; VersionField0 = 1.0.0.0
; VersionField1 = 2.5.26.218
; VersionField2 = CTEI - Communauté Tunisienne des Enseignants d'Informatique
; VersionField3 = BacBackup
; VersionField4 = 2.5.26
; VersionField5 = 1.0.0.1
; VersionField6 = Watchdog pour BacBackup
; VersionField9 = 2016-2026 © Communauté Tunisienne des Enseignants d'Informatique
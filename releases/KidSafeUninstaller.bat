@echo off
setlocal EnableDelayedExpansion
title KidSafe - Desinstalador Universal
color 1F

REM ============================================================
REM  KidSafe Desinstalador Universal v2.0
REM  Elimina TODO rastro del agente KidSafe de este equipo:
REM  servicio, tareas, auto-arranque, hosts, politicas, archivos.
REM  No requiere claves ni conexion. Solo para Windows.
REM ============================================================

REM ---- Auto-elevacion a Administrador (UAC) ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [i] Se requieren permisos de Administrador.
    echo      Abriendo el cuadro de UAC...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo.
echo  ============================================================
echo       KIDSAFE - DESINSTALADOR UNIVERSAL  (v2.0)
echo  ============================================================
echo.
echo   Este programa eliminara completamente el agente KidSafe:
echo     [1] Servicio de Windows
echo     [2] Tareas programadas (4)
echo     [3] Auto-arranque (registro + carpeta Inicio)
echo     [4] Filtros web (archivo hosts)
echo     [5] Politicas de restrinccion (registro)
echo     [6] Archivos del programa y datos
echo.
echo   NO requiere clave de desinstalacion.
echo.
echo  ------------------------------------------------------------
echo.
set /p CONFIRM=  Escribe SI (mayusculas) para eliminar KidSafe: 
if /I not "%CONFIRM%"=="SI" (
    echo.
    echo  [i] Cancelado. No se elimino nada.
    timeout /t 3 >nul
    exit /b
)

echo.
echo  ============================================================
echo   INICIANDO DESINSTALACION...
echo  ============================================================
echo.

echo  [1/7] Deteniendo procesos KidSafeAgent...
taskkill /F /IM KidSafeAgent.exe >nul 2>&1
if %errorlevel%==0 (echo         OK: procesos finalizados) else (echo         No habia procesos activos)

echo  [2/7] Deteniendo y eliminando el servicio...
sc stop KidSafeAgent >nul 2>&1
timeout /t 2 /nobreak >nul
sc delete KidSafeAgent >nul 2>&1
if %errorlevel%==0 (echo         OK: servicio eliminado) else (echo         El servicio no estaba instalado)

echo  [3/7] Eliminando tareas programadas...
schtasks /Delete /TN KidSafeWatchdog /F >nul 2>&1 && echo         OK: KidSafeWatchdog
schtasks /Delete /TN KidSafeUpdater  /F >nul 2>&1 && echo         OK: KidSafeUpdater
schtasks /Delete /TN KidSafeAgent    /F >nul 2>&1 && echo         OK: KidSafeAgent
schtasks /Delete /TN KidSafeWebFilter /F >nul 2>&1 && echo         OK: KidSafeWebFilter
schtasks /Delete /TN KidSafeCleanup  /F >nul 2>&1
echo         (las que no existian se omiten)

echo  [4/7] Eliminando auto-arranque...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v KidSafeAgent /f >nul 2>&1
if exist "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\KidSafeAgent.lnk" (
    del /f /q "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\KidSafeAgent.lnk" >nul 2>&1
    echo         OK: atajo de inicio eliminado
) else (
    echo         No habia atajo de inicio
)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v KidSafeAgent /f >nul 2>&1

echo  [5/7] Restaurando archivo hosts (filtros web)...
set "HOSTS=C:\Windows\System32\drivers\etc\hosts"
if exist "%HOSTS%.kidsafe_bak" (
    copy /y "%HOSTS%.kidsafe_bak" "%HOSTS%" >nul 2>&1
    del /f /q "%HOSTS%.kidsafe_bak" >nul 2>&1
    echo         OK: hosts restaurado desde copia de seguridad
) else (
    findstr /V /B /C:"0.0.0.0" /C:"# BEGIN KidSafe" /C:"# END KidSafe" /C:"# Generado por KidSafe" "%HOSTS%" > "%TEMP%\hosts_clean" 2>nul
    if exist "%TEMP%\hosts_clean" (
        copy /y "%TEMP%\hosts_clean" "%HOSTS%" >nul 2>&1
        del /f /q "%TEMP%\hosts_clean" >nul 2>&1
        echo         OK: entradas de bloqueo eliminadas del hosts
    ) else (
        echo         El hosts ya estaba limpio
    )
)
ipconfig /flushdns >nul 2>&1

echo  [6/7] Limpiando politicas de restrinccion...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableTaskMgr /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRun /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRun /f >nul 2>&1
echo         OK: politicas eliminadas (si existian)

echo  [7/7] Eliminando archivos...
if exist "C:\Program Files\KidSafe" (
    rmdir /s /q "C:\Program Files\KidSafe" >nul 2>&1
    if exist "C:\Program Files\KidSafe" (
        echo         El exe estaba en uso: se movera y borrara al reiniciar.
        move /y "C:\Program Files\KidSafe" "C:\ProgramData\KidSafe_PendDelete" >nul 2>&1
        schtasks /Create /TN KidSafeCleanup /TR "cmd /c rmdir /s /q C:\ProgramData\KidSafe_PendDelete" /SC ONSTART /RU SYSTEM /RL HIGHEST /F >nul 2>&1
    ) else (
        echo         OK: C:\Program Files\KidSafe eliminado
    )
) else (
    echo         No habia archivos de programa
)
if exist "C:\ProgramData\KidSafe" rmdir /s /q "C:\ProgramData\KidSafe" >nul 2>&1
if exist "C:\ProgramData\KidSafe_PendingDelete" rmdir /s /q "C:\ProgramData\KidSafe_PendingDelete" >nul 2>&1

echo.
echo  ============================================================
echo   DESINSTALACION COMPLETADA
echo  ============================================================
echo.
echo   El equipo quedo limpio de KidSafe.
echo   (Si quedo algo pendiente, se borrara al reiniciar.)
echo.
echo   Verificacion rapida:
sc query KidSafeAgent 2>&1 | findstr /C:"STATE" >nul && (echo     [!] El servicio sigue - reinicia el PC) || (echo     [x] Servicio: eliminado)
schtasks /Query /TN KidSafeWatchdog >nul 2>&1 && (echo     [!] Tareas siguen - reinicia el PC) || (echo     [x] Tareas: eliminadas)
if exist "C:\Program Files\KidSafe" (echo     [!] Archivos: quedan - se borran al reiniciar) else (echo     [x] Archivos: eliminados)
echo.
pause
exit /b

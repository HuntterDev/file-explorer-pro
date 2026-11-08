@echo off
title Atualizando Menu Interativo...

echo.
echo ==============================================
echo    Atualizando Menu Interativo...
echo    Escaneando pastas e arquivos...
echo ==============================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_gerar_menu.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Menu atualizado com sucesso!
    echo Abrindo no navegador...
    start "" "%~dp0Menu_Interativo.html"
) else (
    echo.
    echo Erro ao gerar o menu.
    pause
)

timeout /t 2 >nul

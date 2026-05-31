@echo off
REM ec_lifeinvader — Test-Daten in ESXLegacy_F9E16F importieren (Laragon)
setlocal EnableDelayedExpansion

set DBNAME=ESXLegacy_F9E16F
set SQL=%~dp0seed_test_esx.sql
set MYSQL=
set LARAGON=C:\laragon

if exist "%LARAGON%\bin\mysql\mysql-8.4.7-winx64\bin\mysql.exe" (
  set "MYSQL=%LARAGON%\bin\mysql\mysql-8.4.7-winx64\bin\mysql.exe"
)
if not defined MYSQL if exist "%LARAGON%\bin\mysql\mariadb-12.2.2-winx64\bin\mysql.exe" (
  set "MYSQL=%LARAGON%\bin\mysql\mariadb-12.2.2-winx64\bin\mysql.exe"
)
if not defined MYSQL (
  for /d %%D in ("%LARAGON%\bin\mysql\mysql-*") do (
    if exist "%%D\bin\mysql.exe" set "MYSQL=%%D\bin\mysql.exe"
  )
)
if not defined MYSQL (
  for /d %%D in ("%LARAGON%\bin\mysql\mariadb-*") do (
    if exist "%%D\bin\mysql.exe" set "MYSQL=%%D\bin\mysql.exe"
  )
)
if not defined MYSQL (
  where mysql >nul 2>&1
  if not errorlevel 1 set MYSQL=mysql
)

if not defined MYSQL (
  echo mysql.exe nicht gefunden. Laragon gestartet? Oder: npm run seed:esx
  exit /b 1
)

echo Importiere %SQL% nach %DBNAME% ...
echo MySQL: !MYSQL!
"!MYSQL!" -u root -h localhost %DBNAME% < "%SQL%"
if errorlevel 1 (
  echo Import fehlgeschlagen.
  exit /b 1
)

echo Fertig. Test-Chars: char1:litest001 bis char1:litest005
exit /b 0

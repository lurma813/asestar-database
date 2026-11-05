@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Upload Screentime - ASESTAR (Batch + Chunk 500)

:: ============================================================
:: KONFIGURASI
:: ============================================================
set BASE_URL=http://localhost:1111
set TXT_FILE=siswa.txt
set DAYS=30
set CHUNK_SIZE=500
set CURL_TIMEOUT=120

:: ============================================================
:: CEK DEPENDENSI
:: ============================================================
if not exist "%TXT_FILE%" (
    echo [x] File "%TXT_FILE%" tidak ditemukan.
    pause & exit /b 1
)
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo [x] curl.exe tidak ada. Butuh Windows 10 1803+.
    pause & exit /b 1
)
where powershell >nul 2>&1
if errorlevel 1 (
    echo [x] PowerShell tidak ditemukan.
    pause & exit /b 1
)

:: ============================================================
:: MENU
:: ============================================================
:MENU
cls
echo ============================================================
echo   UPLOAD SCREENTIME - BATCH + CHUNK
echo ============================================================
echo   Base URL  : %BASE_URL%
echo   TXT       : %TXT_FILE%
echo   Hari      : %DAYS%
echo   Chunk     : %CHUNK_SIZE% item per upload
echo ------------------------------------------------------------
echo   [1] Upload semua siswa
echo   [2] Upload 1 siswa (input NISN)
echo   [3] Ubah jumlah hari (sekarang: %DAYS%)
echo   [4] Ubah Base URL (sekarang: %BASE_URL%)
echo   [5] Tampilkan daftar siswa
echo   [0] Keluar
echo ============================================================
set /p PILIH="Pilih: "

if "%PILIH%"=="1" goto UPLOAD_ALL
if "%PILIH%"=="2" goto UPLOAD_ONE
if "%PILIH%"=="3" goto SET_DAYS
if "%PILIH%"=="4" goto SET_URL
if "%PILIH%"=="5" goto LIST
if "%PILIH%"=="0" goto END
goto MENU

:SET_DAYS
set /p DAYS="Jumlah hari (1-365): "
goto MENU

:SET_URL
set /p BASE_URL="Base URL: "
goto MENU

:: ============================================================
:: LIST SISWA
:: ============================================================
:LIST
cls
echo Daftar siswa di %TXT_FILE%:
echo.
set /a NO=0
set /a LINE=0
for /f "usebackq delims=" %%A in ("%TXT_FILE%") do (
    set /a LINE+=1
    set /a MOD=!LINE! %% 2
    if !MOD!==1 (
        set "NAMA=%%A"
    ) else (
        set /a NO+=1
        echo   !NO!. !NAMA! - %%A
    )
)
echo.
echo Total: !NO! siswa
pause
goto MENU

:: ============================================================
:: UPLOAD SEMUA SISWA
:: ============================================================
:UPLOAD_ALL
cls
echo [i] Upload semua siswa, %DAYS% hari, ke %BASE_URL%
echo.

:: Cek jumlah baris genap
set /a TOTAL_LINES=0
for /f "usebackq delims=" %%A in ("%TXT_FILE%") do set /a TOTAL_LINES+=1
set /a MOD=TOTAL_LINES %% 2
if not !MOD!==0 (
    echo [x] Jumlah baris di %TXT_FILE% ganjil: !TOTAL_LINES!
    echo     Format: baris ganjil=Nama, genap=NISN. Harus genap.
    pause
    goto MENU
)

:: Pre-process ke file temp: NISN|NAMA
set "TEMP_LIST=%TEMP%\siswa_list_%RANDOM%.txt"
if exist "!TEMP_LIST!" del "!TEMP_LIST!"

set /a LINE=0
set "LAST_NAMA="
for /f "usebackq delims=" %%A in ("%TXT_FILE%") do (
    set /a LINE+=1
    set /a MOD=!LINE! %% 2
    if !MOD!==1 (
        set "LAST_NAMA=%%A"
    ) else (
        >>"!TEMP_LIST!" echo %%A^|!LAST_NAMA!
    )
)

set /a NO=0
set /a OK=0
set /a FAIL=0

for /f "usebackq tokens=1,* delims=|" %%X in ("!TEMP_LIST!") do (
    set /a NO+=1
    call :PROSES_SISWA "!NO!" "%%Y" "%%X"
)

del "!TEMP_LIST!" 2>nul

echo.
echo ============================================================
echo Selesai: !OK! sukses, !FAIL! gagal dari !NO! siswa
echo ============================================================
pause
goto MENU

:: ============================================================
:: UPLOAD 1 SISWA
:: ============================================================
:UPLOAD_ONE
cls
set /p NISN_TARGET="Masukkan NISN: "
if "%NISN_TARGET%"=="" goto MENU

set /a LINE=0
set FOUND=0
set "NAMA_TARGET="
for /f "usebackq delims=" %%A in ("%TXT_FILE%") do (
    set /a LINE+=1
    set /a MOD=!LINE! %% 2
    if !MOD!==1 (
        set "NAMA=%%A"
    ) else (
        if "%%A"=="%NISN_TARGET%" (
            set "NAMA_TARGET=!NAMA!"
            set FOUND=1
        )
    )
)

if !FOUND!==0 (
    echo [x] NISN %NISN_TARGET% tidak ditemukan di %TXT_FILE%
    pause
    goto MENU
)

echo [i] Ketemu: !NAMA_TARGET! (%NISN_TARGET%)
set /a OK=0
set /a FAIL=0
call :PROSES_SISWA "1" "!NAMA_TARGET!" "%NISN_TARGET%"
echo.
echo Selesai: !OK! sukses, !FAIL! gagal
pause
goto MENU

:: ============================================================
:: SUBROUTINE: PROSES 1 SISWA (chunk 500)
::   %1 = nomor, %2 = nama, %3 = nisn
:: ============================================================
:PROSES_SISWA
set "P_NO=%~1"
set "P_NAMA=%~2"
set "P_NISN=%~3"
set "P_DEV=TEST-%P_NISN%"

echo [!P_NO!] !P_NAMA! (!P_NISN!)

:: ------------------------------------------------------------
:: 1. LOGIN
:: ------------------------------------------------------------
set "LOGIN_BODY={\"nisn\":\"!P_NISN!\",\"nama\":\"!P_NAMA!\",\"device_id\":\"!P_DEV!\",\"model\":\"Test\"}"
set "HTTP_CODE=000"
for /f "delims=" %%R in ('curl -s -o nul -w "%%{http_code}" --max-time 30 -X POST "%BASE_URL%/login" -H "Content-Type: application/json" -H "X-Device-Id: !P_DEV!" -d "!LOGIN_BODY!"') do set "HTTP_CODE=%%R"

if not "!HTTP_CODE!"=="200" (
    echo   [x] Login gagal: HTTP !HTTP_CODE!
    set /a FAIL+=1
    exit /b 1
)
echo   [+] Login OK

:: ------------------------------------------------------------
:: 2. GENERATE SESI + PECAH JADI CHUNK 500
:: ------------------------------------------------------------
set "CHUNK_DIR=%TEMP%\chunks_!P_NISN!_%RANDOM%"
mkdir "!CHUNK_DIR!" 2>nul
if not exist "!CHUNK_DIR!" (
    echo   [x] Gagal buat folder temp: !CHUNK_DIR!
    set /a FAIL+=1
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$nisn='!P_NISN!'; $nama='!P_NAMA!'; $dev='!P_DEV!'; $days=%DAYS%; $chunkSize=%CHUNK_SIZE%; $dir='!CHUNK_DIR!';" ^
  "$appNames=@('Mobile Legends','WhatsApp','Chrome','YouTube','TikTok','Instagram','Facebook','Telegram','Free Fire','PUBG Mobile','Genshin Impact','Spotify','Google Maps','Kamera','Galeri','Play Store','Shopee','Tokopedia','Gojek','Grab','Zoom','Google Meet','Discord','Twitter/X','Netflix','CapCut','Canva','WPS Office','Google Docs','Kalkulator');" ^
  "$appPkgs=@('com.mobile.legends','com.whatsapp','com.android.chrome','com.google.android.youtube','com.zhiliaoapp.musically','com.instagram.android','com.facebook.katana','org.telegram.messenger','com.dts.freefireth','com.tencent.ig','com.miHoYo.GenshinImpact','com.spotify.music','com.google.android.apps.maps','com.android.camera','com.android.gallery3d','com.android.vending','com.shopee.id','com.tokopedia.tkpd','com.gojek.app','com.grabtaxi.passenger','us.zoom.videomeetings','com.google.android.apps.meetings','com.discord','com.twitter.android','com.netflix.mediaclient','com.lemon.lvoverseas','com.canva.editor','cn.wps.moffice_eng','com.google.android.apps.docs','com.google.android.calculator');" ^
  "$heavyNames=@('Mobile Legends','Free Fire','PUBG Mobile','Genshin Impact','YouTube','Netflix');" ^
  "$heavyPkgs=@('com.mobile.legends','com.dts.freefireth','com.tencent.ig','com.miHoYo.GenshinImpact','com.google.android.youtube','com.netflix.mediaclient');" ^
  "$today=(Get-Date).Date; $sessions=New-Object System.Collections.ArrayList;" ^
  "function New-Sesi($st,$du,$nm,$pk) { return [pscustomobject]@{package=$pk; app_name=$nm; start=$st.ToString('yyyy-MM-dd HH:mm:ss'); end=$st.AddMinutes($du).ToString('yyyy-MM-dd HH:mm:ss'); duration=($du*60)} }" ^
  "for ($d=$days-1; $d -ge 0; $d--) {" ^
  "  $day=$today.AddDays(-$d); $n=Get-Random -Minimum 5 -Maximum 21;" ^
  "  for ($i=0; $i -lt $n; $i++) {" ^
  "    $slotMin=Get-Random -Minimum 360 -Maximum 1436;" ^
  "    $start=$day.AddMinutes($slotMin);" ^
  "    $dur=Get-Random -Minimum 1 -Maximum 46;" ^
  "    $end=$start.AddMinutes($dur);" ^
  "    if ($end.Date -ne $day) { $end=$day.AddHours(23).AddMinutes(59).AddSeconds(59); $dur=[int](($end-$start).TotalMinutes) };" ^
  "    if ($dur -lt 1) { continue };" ^
  "    $idx=Get-Random -Minimum 0 -Maximum $appNames.Count;" ^
  "    [void]$sessions.Add((New-Sesi $start $dur $appNames[$idx] $appPkgs[$idx]))" ^
  "  }" ^
  "  if ((Get-Random -Maximum 100) -lt 35) {" ^
  "    $h=Get-Random -Minimum 22 -Maximum 24; $m=Get-Random -Minimum 0 -Maximum 60;" ^
  "    $start=$day.AddHours($h).AddMinutes($m);" ^
  "    $dur=Get-Random -Minimum 60 -Maximum 301;" ^
  "    $idx=Get-Random -Minimum 0 -Maximum $heavyNames.Count;" ^
  "    [void]$sessions.Add((New-Sesi $start $dur $heavyNames[$idx] $heavyPkgs[$idx]))" ^
  "  }" ^
  "}" ^
  "$sorted = $sessions | Sort-Object start;" ^
  "$idx=0;" ^
  "for ($i=0; $i -lt $sorted.Count; $i+=$chunkSize) {" ^
  "  $end=[Math]::Min($i+$chunkSize-1, $sorted.Count-1);" ^
  "  $chunk=$sorted[$i..$end];" ^
  "  if ($chunk -isnot [array]) { $chunk=@($chunk) };" ^
  "  $payload=@{nisn=$nisn; nama=$nama; device_id=$dev; model='Test'; data=$chunk} | ConvertTo-Json -Compress -Depth 10;" ^
  "  $f=Join-Path $dir ('chunk_' + $idx + '.json');" ^
  "  [IO.File]::WriteAllText($f, $payload, [Text.UTF8Encoding]::new($false));" ^
  "  $idx++;" ^
  "}" ^
  "Write-Host ('  [i] Total sesi: ' + $sorted.Count + ', chunk: ' + $idx)"

if errorlevel 1 (
    echo   [x] Gagal generate sesi
    rmdir /s /q "!CHUNK_DIR!" 2>nul
    set /a FAIL+=1
    exit /b 1
)

:: ------------------------------------------------------------
:: 3. UPLOAD PER CHUNK
:: ------------------------------------------------------------
set /a CHUNK_IDX=0
set /a CHUNK_FAIL=0
set /a SISWA_BARU=0
set /a SISWA_UPDATE=0
set /a SISWA_GAGAL=0

:CHUNK_LOOP
set "CHUNK_FILE=!CHUNK_DIR!\chunk_!CHUNK_IDX!.json"
if not exist "!CHUNK_FILE!" goto CHUNK_DONE

set "RESP_FILE=!CHUNK_DIR!\resp_!CHUNK_IDX!.json"
set "HTTP_CODE=000"
for /f "delims=" %%R in ('curl -s -o "!RESP_FILE!" -w "%%{http_code}" --max-time %CURL_TIMEOUT% -X POST "%BASE_URL%/screentime" -H "Content-Type: application/json" -H "X-Device-Id: !P_DEV!" --data-binary "@!CHUNK_FILE!"') do set "HTTP_CODE=%%R"

if not "!HTTP_CODE!"=="200" (
    echo   [x] Chunk !CHUNK_IDX! gagal: HTTP !HTTP_CODE!
    if exist "!RESP_FILE!" (
        echo     --- respons server ---
        type "!RESP_FILE!"
        echo     ----------------------
    )
    set /a CHUNK_FAIL+=1
    set /a CHUNK_IDX+=1
    goto CHUNK_LOOP
)

set "RESP_BODY="
for /f "usebackq delims=" %%L in ("!RESP_FILE!") do set "RESP_BODY=!RESP_BODY!%%L"

:: parse ringan: cari angka baru, diperbarui, gagal
set "B_BARU=0"
set "B_UPDATE=0"
set "B_GAGAL=0"
echo !RESP_BODY! | findstr /c:"\"baru\":" >nul
if !errorlevel!==0 (
    for /f "tokens=2 delims=:,}" %%V in ('echo !RESP_BODY! ^| findstr /c:"\"baru\":"') do set "B_BARU=%%V"
    for /f "tokens=2 delims=:,}" %%V in ('echo !RESP_BODY! ^| findstr /c:"\"diperbarui\":"') do set "B_UPDATE=%%V"
    for /f "tokens=2 delims=:,}" %%V in ('echo !RESP_BODY! ^| findstr /c:"\"gagal\":"') do set "B_GAGAL=%%V"
)
set "B_BARU=!B_BARU: =!"
set "B_UPDATE=!B_UPDATE: =!"
set "B_GAGAL=!B_GAGAL: =!"

echo   [+] Chunk !CHUNK_IDX! OK: baru=!B_BARU! update=!B_UPDATE! gagal=!B_GAGAL!
set /a SISWA_BARU+=!B_BARU!
set /a SISWA_UPDATE+=!B_UPDATE!
set /a SISWA_GAGAL+=!B_GAGAL!

set /a CHUNK_IDX+=1
goto CHUNK_LOOP

:CHUNK_DONE
echo   [i] Total chunk: !CHUNK_IDX!, chunk gagal: !CHUNK_FAIL!, sesi baru: !SISWA_BARU!, update: !SISWA_UPDATE!

if !CHUNK_FAIL! GTR 0 (
    set /a FAIL+=1
) else (
    set /a OK+=1
)

rmdir /s /q "!CHUNK_DIR!" 2>nul
exit /b 0

:END
endlocal
exit /b 0
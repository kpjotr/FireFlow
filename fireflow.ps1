<#
.SYNOPSIS
    FireFlow - Univerzális Firebase Deploy, Git Branch és Verziókezelő CLI Eszköz
.DESCRIPTION
    Kezeli a Firebase projektek (Hosting, Functions, Firestore, Storage) éles és preview 
    deploy folyamatát, szinkronban tartva a HTML fájlokban megjelenő verziószámot a Git tagekkel.

    Copyright (C) 2026

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

param(
    [Parameter(Position=0)]
    [Alias("CM")]
    [string]$CommitMessage = "",

    [Parameter(Position=1)]
    [Alias("R")]
    [ValidateSet("patch", "minor", "major")]
    [string]$ReleaseType = "patch",

    [Parameter()]
    [Alias("M")]
    [ValidateSet("live", "preview", "promote")]
    [string]$Mode = "live",

    [Parameter()]
    [Alias("P")]
    [switch]$Preview,

    [Parameter()]
    [Alias("PR")]
    [switch]$Promote,

    [Parameter()]
    [Alias("T")]
    [string]$Target = "",

    [Parameter()]
    [Alias("O")]
    [string]$Only = "hosting",

    [Parameter()]
    [Alias("C")]
    [string]$Channel = "preview",

    [Parameter()]
    [Alias("B")]
    [string]$MainBranch = "main",

    [Parameter()]
    [Alias("S")]
    [switch]$SkipHostingSync,

    [Parameter()]
    [Alias("Y")]
    [switch]$Yes,

    [Parameter()]
    [Alias("I")]
    [switch]$Install,

    [Parameter()]
    [Alias("V")]
    [switch]$Version,

    [Parameter()]
    [Alias("H", "?")]
    [switch]$Help
)

# =====================================================================
# ESZKÖZ ÖNVERZIÓZÁSA (Antigravity frissíti a saját repó alapján)
# =====================================================================
$ToolName = "FireFlow"
$ToolVersion = "v1.1.0"

$ErrorActionPreference = "Stop"

# UTF-8 kódolás beállítása a konzolhoz
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}

function Show-Help {
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor DarkCyan
    Write-Host "  $ToolName CLI ($ToolVersion) - Univerzális Firebase & Git Kiadáskezelő" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "HASZNÁLAT:" -ForegroundColor Yellow
    Write-Host "  fireflow [CommitMessage] [ReleaseType] [Kapcsolók...]"
    Write-Host "  (Vagy: .\fireflow.ps1 [CommitMessage] [ReleaseType] [Kapcsolók...])"
    Write-Host ""
    Write-Host "GYORS MÓDVÁLASZTÓ KAPCSOLÓK:" -ForegroundColor Yellow
    Write-Host "  (alapértelmezett)       Éles (live) kiadás a főágon"
    Write-Host "  -P,  -Preview           Teszt kiadás Firebase Preview csatornára és külön Git ágra"
    Write-Host "  -PR, -Promote           Preview ág beolvasztása (merge) a főágba és éles kiadás"
    Write-Host ""
    Write-Host "PARAMÉTEREK ÉS RÖVIDÍTÉSEK:" -ForegroundColor Yellow
    Write-Host "  -CM     <szöveg>        Commit üzenet (1. pozicionális paraméter, elhagyható a -CM)"
    Write-Host "  -R      <típus>         Verzióléptetés: patch (alap), minor, major (2. pozicionális)"
    Write-Host "  -M      <mód>           Működési mód explicit megadása: live, preview, promote"
    Write-Host "  -C      <csatorna>      Preview csatorna és Git ág neve (alapértelmezett: 'preview')"
    Write-Host "  -T      <target>        Firebase Hosting target neve (multi-site projektekhez)"
    Write-Host "  -O      <komponensek>   Deploy szűrése (alap: 'hosting', pl. 'firestore:rules,functions')"
    Write-Host "  -B      <ág>            Fő Git ág neve (alapértelmezett: 'main', vagy 'master')"
    Write-Host "  -S,  -SkipHostingSync   HTML verziószinkron (automatikus hosting deploy) kihagyása"
    Write-Host "  -Y,  -Yes               Interaktív [I/N] jóváhagyás átugrása (azonnali futtatás)"
    Write-Host "  -I,  -Install           Globális parancs ('fireflow') regisztrálása a PowerShell profilban"
    Write-Host "  -V,  -Version           Kiírja a $ToolName aktuális verziószámát"
    Write-Host "  -H,  -Help, -?          Megjeleníti ezt a súgót"
    Write-Host ""
    Write-Host "GLOBÁLIS HASZNÁLAT:" -ForegroundColor Yellow
    Write-Host "  A 'fireflow -Install' futtatása után a parancs bármely projekt könyvtárából elérhető."
    Write-Host ""
    Write-Host "GYAKORLATI PÉLDÁK (PUSKÁZÓ):" -ForegroundColor Yellow
    Write-Host "  1. Gyors éles (patch) kiadás:" -ForegroundColor Cyan
    Write-Host "     .\fireflow.ps1 `"Hibajavítás a főoldalon`""
    Write-Host ""
    Write-Host "  2. Éles (minor) kiadás egy adott hosting targetre:" -ForegroundColor Cyan
    Write-Host "     .\fireflow.ps1 `"Új modul`" minor -T app"
    Write-Host ""
    Write-Host "  3. Csak Firestore szabályok frissítése (HTML verziószinkronnal együtt):" -ForegroundColor Cyan
    Write-Host "     .\fireflow.ps1 `"Szabályok szigorítása`" -O firestore:rules"
    Write-Host ""
    Write-Host "  4. Fejlesztés küldése Preview csatornára (és 'preview/teszt' Git ágra):" -ForegroundColor Cyan
    Write-Host "     .\fireflow.ps1 `"Új naptár teszt`" -P -C teszt -T app"
    Write-Host ""
    Write-Host "  5. Letesztelt Preview ág beolvasztása (merge) és élesítése:" -ForegroundColor Cyan
    Write-Host "     .\fireflow.ps1 -PR -C teszt -T app"
    Write-Host ""
}

if ($Help) {
    Show-Help
    exit 0
}

if ($Version) {
    Write-Host "$ToolName CLI - Verzió: $ToolVersion" -ForegroundColor Cyan
    exit 0
}

if ($Install) {
    $ScriptFullPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($ScriptFullPath)) {
        $ScriptFullPath = $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($ScriptFullPath)) {
        $ScriptFullPath = $MyInvocation.MyCommand.Definition
    }

    $ProfilePath = $PROFILE
    $ProfileDir = Split-Path -Parent $ProfilePath

    if (-not (Test-Path $ProfileDir)) {
        New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    }

    if (-not (Test-Path $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }

    $ProfileContent = Get-Content -Path $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $ProfileContent) { $ProfileContent = "" }

    $FunctionDef = "`r`n# FireFlow CLI Global Function`r`nfunction fireflow { & `"$ScriptFullPath`" @args }`r`n"

    if ($ProfileContent -match 'function\s+fireflow\b') {
        $Pattern = '(?ms)([\r\n]*# FireFlow CLI Global Function[\r\n]*)?function\s+fireflow\s*\{[^}]*\}[\r\n]*'
        $CleanedContent = [regex]::Replace($ProfileContent, $Pattern, '').TrimEnd()
        $NewProfileContent = $CleanedContent + "`r`n`r`n# FireFlow CLI Global Function`r`nfunction fireflow { & `"$ScriptFullPath`" @args }`r`n"
        Set-Content -Path $ProfilePath -Value $NewProfileContent -Encoding UTF8
        Write-Host ""
        Write-Host "[FireFlow] A globális parancs sikeresen frissítve a PowerShell profilodban!" -ForegroundColor Green
    } else {
        Add-Content -Path $ProfilePath -Value $FunctionDef -Encoding UTF8
        Write-Host ""
        Write-Host "[FireFlow] A globális parancs sikeresen regisztrálva a PowerShell profilodban!" -ForegroundColor Green
    }

    Write-Host "Profil fájl: $ProfilePath" -ForegroundColor DarkCyan
    Write-Host "Mostantól bármely Firebase projekt könyvtárából futtatható a 'fireflow' parancs." -ForegroundColor Green
    Write-Host "Azonnali használathoz töltsd újra a profilodat vagy nyiss új terminált:" -ForegroundColor Yellow
    Write-Host "  . `$PROFILE" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

function Fail($Message) {
    Write-Host ""
    Write-Host "[$ToolName HIBA]: $Message" -ForegroundColor Red
    exit 1
}

function Write-Header($Title) {
    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor DarkCyan
    Write-Host "  $ToolName ($ToolVersion) - $Title" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor DarkCyan
}

# Gyorskapcsolók (-P és -PR) feloldása és ütközésellenőrzése
if ($Preview -and $Promote) {
    Fail "A -Preview (-P) és -Promote (-PR) kapcsolók nem használhatók egyszerre!"
}
if ($Preview) { $Mode = "preview" }
if ($Promote) { $Mode = "promote" }

# 1. Alapvető környezet ellenőrzése
$ProjectRoot = (Get-Location).Path

if (-not (Test-Path ".\.git")) { Fail "Ez a mappa nem egy Git repository." }
if (-not (Test-Path ".\firebase.json")) { Fail "A firebase.json nem található a projekt gyökerében." }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "A 'git' parancs nem található." }
$FirebaseCmd = if (Get-Command firebase -ErrorAction SilentlyContinue) { "firebase" } 
               elseif (Get-Command firebase.cmd -ErrorAction SilentlyContinue) { "firebase.cmd" } 
               else { Fail "A Firebase CLI ('firebase') nem található." }

# 2. Aktuális Git ág és státusz lekérdezése
$CurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$GitStatus = @(git status --porcelain)

# Ha a megadott MainBranch (pl. main) nem létezik, de van master, használjuk azt
$branchCheck = @(git branch --list $MainBranch)
if ($branchCheck.Count -eq 0 -and @(git branch --list "master").Count -gt 0) {
    $MainBranch = "master"
}

# 3. Legutóbbi stabil (vX.Y.Z) verzió megkeresése
$stableTags = @(git tag --list "v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
$baseVersion = if ($stableTags.Count -gt 0) { $stableTags[0] } else { "v0.1.0" }

if ($baseVersion -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
    Fail "Érvénytelen alapverzió formátum: $baseVersion"
}

$major = [int]$Matches[1]
$minor = [int]$Matches[2]
$patch = [int]$Matches[3]

switch ($ReleaseType) {
    "patch" { $patch++ }
    "minor" { $minor++; $patch = 0 }
    "major" { $major++; $minor = 0; $patch = 0 }
}

$nextBaseVersion = "v$major.$minor.$patch"

# Verziószám és célág meghatározása a mód alapján
$NewVersion = $nextBaseVersion
$TargetBranch = $CurrentBranch

if ($Mode -eq "preview") {
    $safeChannel = $Channel -replace '[^a-zA-Z0-9_-]', '-'
    if ($CurrentBranch -eq $MainBranch) {
        $TargetBranch = "preview/$safeChannel"
    }
    
    # Megkeressük az adott alapverzióhoz tartozó legmagasabb preview build számot
    $previewTags = @(git tag --list "$nextBaseVersion-preview.*" --sort=-v:refname)
    $buildNum = 1
    if ($previewTags.Count -gt 0 -and $previewTags[0] -match '\.(\d+)$') {
        $buildNum = [int]$Matches[1] + 1
    }
    $NewVersion = "$nextBaseVersion-preview.$buildNum"
}
elseif ($Mode -eq "promote") {
    $TargetBranch = $MainBranch
    $SourceBranch = if ($CurrentBranch -ne $MainBranch) { $CurrentBranch } else { "preview/$Channel" }
}

# 4. Firebase.json elemzése és HTML fájlok felderítése
$firebaseConfig = Get-Content ".\firebase.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$publicDirs = @()

if ($firebaseConfig.hosting) {
    if ($firebaseConfig.hosting -is [System.Array]) {
        foreach ($h in $firebaseConfig.hosting) {
            if ([string]::IsNullOrWhiteSpace($Target) -or $h.target -eq $Target) {
                if ($h.public) { $publicDirs += $h.public }
            }
        }
    } else {
        if ($firebaseConfig.hosting.public) {
            $publicDirs += $firebaseConfig.hosting.public
        }
    }
}

# Verzió placeholdert (__VERSION__) tartalmazó HTML fájlok megkeresése
$VersionFiles = @()
foreach ($dir in $publicDirs) {
    $fullDir = Join-Path $ProjectRoot $dir
    if (Test-Path $fullDir) {
        $htmlFiles = Get-ChildItem -Path $fullDir -Filter "*.html" -Recurse -File
        foreach ($file in $htmlFiles) {
            $content = Get-Content $file.FullName -Raw -Encoding UTF8
            if ($content -match '__VERSION__') {
                $VersionFiles += $file.FullName
            }
        }
    }
}

# 5. Deploy célok (Only / Target) összeállítása
$HostingTargetStr = if ([string]::IsNullOrWhiteSpace($Target)) { "hosting" } else { "hosting:$Target" }
$DeployOnlyList = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })

# Ha van verziózott HTML fájl, biztosítjuk, hogy a hosting is frissüljön (kivéve ha letiltották)
if (-not $SkipHostingSync -and $VersionFiles.Count -gt 0) {
    $hasHosting = $false
    foreach ($item in $DeployOnlyList) {
        if ($item -eq "hosting" -or $item.StartsWith("hosting:")) {
            $hasHosting = $true
            break
        }
    }
    if (-not $hasHosting) {
        $DeployOnlyList += $HostingTargetStr
    }
}

# Ha a felhasználó sima "hosting"-ot írt, de megadott -Target paramétert, pontosítjuk
if (-not [string]::IsNullOrWhiteSpace($Target)) {
    $DeployOnlyList = @($DeployOnlyList | ForEach-Object {
        if ($_ -eq "hosting") { "hosting:$Target" } else { $_ }
    })
}

$FinalOnlyParam = $DeployOnlyList -join ","

# 6. Állapotellenőrzés és Commit üzenet bekérése
if ($Mode -ne "promote" -and $GitStatus.Count -eq 0) {
    Fail "Nincs módosított fájl a munkakönyvtárban. A deploy leállt. (Súgó: .\fireflow.ps1 -h)"
}

if ($Mode -eq "promote" -and $GitStatus.Count -gt 0) {
    Fail "A 'promote' (-PR) mód tiszta munkakönyvtárat igényel. Előbb commitold vagy stasheld a változásokat!"
}

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    if ($Mode -eq "promote") {
        $CommitMessage = "Release $NewVersion (Promoted from $SourceBranch)"
    } else {
        $CommitMessage = Read-Host "Add meg a commit üzenetet"
    }
}
if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    Fail "A commit üzenet nem lehet üres!"
}

# 7. Összegzés és Felhasználói Jóváhagyás (Interaktív Fék)
Write-Header "KIADÁSI TERV ($($Mode.ToUpper()))"
Write-Host "Projekt gyökér:    $ProjectRoot"
Write-Host "Jelenlegi Git ág:  $CurrentBranch"
if ($TargetBranch -ne $CurrentBranch) {
    Write-Host "Cél Git ág:        $TargetBranch (Automatikus váltás/létrehozás)" -ForegroundColor Yellow
}
if ($Mode -eq "promote") {
    Write-Host "Beolvasztandó ág:  $SourceBranch -> $MainBranch" -ForegroundColor Magenta
}
Write-Host "Bázis verzió:      $baseVersion"
Write-Host "Új verzió (Tag):   $NewVersion ($ReleaseType)" -ForegroundColor Green
Write-Host "Firebase célok:    $FinalOnlyParam"
if ($Mode -eq "preview") {
    Write-Host "Preview csatorna:  $Channel" -ForegroundColor Cyan
}
Write-Host "Commit üzenet:     $CommitMessage"
Write-Host ""

if ($VersionFiles.Count -gt 0) {
    Write-Host "Verziózandó HTML fájlok (__VERSION__ -> $NewVersion):" -ForegroundColor Cyan
    foreach ($vf in $VersionFiles) {
        $rel = $vf.Substring($ProjectRoot.Length + 1)
        Write-Host "  [HTML] $rel"
    }
} else {
    Write-Host "FIGYELEM: Nem található '__VERSION__' placeholder egyetlen HTML fájlban sem!" -ForegroundColor Yellow
}

if ($GitStatus.Count -gt 0) {
    Write-Host ""
    Write-Host "Módosított / Commitra váró fájlok (ellenőrizd, nincs-e köztük szemét!):" -ForegroundColor Yellow
    foreach ($line in $GitStatus) {
        Write-Host "  $line"
    }
}

Write-Host ""
if (-not $Yes) {
    $confirm = Read-Host "Elindítod a folyamatot ezekkel a beállításokkal? [I/N]"
    if ($confirm -notmatch '^[iIyY]$') {
        Write-Host "Folyamat megszakítva a felhasználó által." -ForegroundColor Yellow
        exit 0
    }
}

# =====================================================================
# 8. VÉGREHAJTÁS: GIT ELŐKÉSZÍTÉS ÉS HELYBEN TÖRTÉNŐ DEPLOY
# =====================================================================

# Branch váltás vagy Merge kezelése
if ($Mode -eq "preview" -and $CurrentBranch -ne $TargetBranch) {
    Write-Host "`nÁtváltás a preview ágra: $TargetBranch..." -ForegroundColor Cyan
    $branchExists = @(git branch --list $TargetBranch)
    if ($branchExists.Count -gt 0) {
        git checkout $TargetBranch
    } else {
        git checkout -b $TargetBranch
    }
    if ($LASTEXITCODE -ne 0) { Fail "Nem sikerült átváltani a(z) $TargetBranch ágra." }
}
elseif ($Mode -eq "promote") {
    Write-Host "`nÁtváltás a főágra ($MainBranch) és '$SourceBranch' beolvasztása..." -ForegroundColor Cyan
    if ($CurrentBranch -ne $MainBranch) {
        git checkout $MainBranch
        if ($LASTEXITCODE -ne 0) { Fail "Nem sikerült átváltani a(z) $MainBranch ágra." }
    }
    git pull origin $MainBranch
    git merge $SourceBranch --no-ff -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { Fail "A Git merge ütközés vagy hiba miatt sikertelen. Oldd fel a konfliktusokat!" }
}

# Eredeti HTML tartalmak mentése a memóriába
$BackupHtmlContent = @{}
try {
    foreach ($vf in $VersionFiles) {
        $rawContent = Get-Content $vf -Raw -Encoding UTF8
        $BackupHtmlContent[$vf] = $rawContent
        $updatedContent = $rawContent.Replace("__VERSION__", $NewVersion)
        Set-Content -Path $vf -Value $updatedContent -Encoding UTF8 -NoNewline
    }

    # FIREBASE DEPLOY FUTTATÁSA
    Write-Host "`nFirebase deploy indítása..." -ForegroundColor Cyan
    
    if ($Mode -eq "preview") {
        # 1. Nem-hosting komponensek deployolása (ha van ilyen megadva)
        $nonHostingTargets = @($DeployOnlyList | Where-Object { $_ -ne "hosting" -and -not $_.StartsWith("hosting:") })
        if ($nonHostingTargets.Count -gt 0) {
            $nhParam = $nonHostingTargets -join ","
            Write-Host "Háttérszolgáltatások frissítése (--only $nhParam)..." -ForegroundColor DarkCyan
            & $FirebaseCmd deploy --only $nhParam
            if ($LASTEXITCODE -ne 0) { Fail "A háttérszolgáltatások deploy-a sikertelen!" }
        }

        # 2. Hosting deploy a Preview Channelre
        $hasHostingTarget = @($DeployOnlyList | Where-Object { $_ -eq "hosting" -or $_.StartsWith("hosting:") }).Count -gt 0
        if ($hasHostingTarget) {
            Write-Host "Hosting feltöltése a(z) '$Channel' preview csatornára..." -ForegroundColor DarkCyan
            if ([string]::IsNullOrWhiteSpace($Target)) {
                & $FirebaseCmd hosting:channel:deploy $Channel
            } else {
                & $FirebaseCmd hosting:channel:deploy $Channel --only $Target
            }
            if ($LASTEXITCODE -ne 0) { Fail "A Firebase preview channel deploy sikertelen!" }
        }
    }
    else {
        # LIVE és PROMOTE mód: teljes éles deploy
        & $FirebaseCmd deploy --only $FinalOnlyParam
        if ($LASTEXITCODE -ne 0) { Fail "A Firebase éles deploy sikertelen!" }
    }
}
finally {
    # GARANTÁLT VISSZAÁLLÍTÁS: A __VERSION__ placeholder visszaírása a forrásfájlokba
    if ($BackupHtmlContent.Count -gt 0) {
        Write-Host "`nForrás HTML fájlok (__VERSION__ placeholder) visszaállítása..." -ForegroundColor DarkGray
        foreach ($vf in $BackupHtmlContent.Keys) {
            Set-Content -Path $vf -Value $BackupHtmlContent[$vf] -Encoding UTF8 -NoNewline
        }
    }
}

# =====================================================================
# 9. GIT COMMIT, TAG ÉS PUSH (Csak sikeres deploy után!)
# =====================================================================
Write-Host "`nGit verziókezelési műveletek végrehajtása..." -ForegroundColor Cyan

if ($Mode -ne "promote") {
    git add -A
    if ($LASTEXITCODE -ne 0) { Fail "A 'git add -A' művelet sikertelen." }

    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { Fail "A Git commit sikertelen." }
}

git tag -a $NewVersion -m $CommitMessage
if ($LASTEXITCODE -ne 0) { Fail "A Git tag ($NewVersion) létrehozása sikertelen." }

$ActiveBranch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host "Feltöltés a távoli repository-ba (origin/$ActiveBranch + $NewVersion)..." -ForegroundColor Cyan
git push -u origin $ActiveBranch
if ($LASTEXITCODE -ne 0) { Fail "A Git branch push sikertelen." }

git push origin $NewVersion
if ($LASTEXITCODE -ne 0) { Fail "A Git tag push sikertelen." }

Write-Header "SIKERES FOLYAMAT!"
Write-Host "Mód:          $($Mode.ToUpper())" -ForegroundColor Green
Write-Host "Aktív ág:     $ActiveBranch" -ForegroundColor Green
Write-Host "Kiadott tag:  $NewVersion" -ForegroundColor Green
Write-Host "Minden változás élesítve és szinkronizálva a GitHub-on!" -ForegroundColor Green
Write-Host ""
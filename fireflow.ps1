<#
.SYNOPSIS
    FireFlow - Universal Firebase Deploy, Git Branch & Version Management CLI Tool / Univerzális Firebase Deploy, Git Branch és Verziókezelő CLI Eszköz
.DESCRIPTION
    English:
    Manages the deployment process of Firebase projects (Hosting, Functions, Firestore, Storage)
    for both live and preview channels, keeping the version number displayed in HTML files
    synchronized with Git tags.

    Magyar:
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
    [Alias("CL")][switch]$Cleanup,

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
    [Alias("Y", "YesToAll")]
    [switch]$Yes,

    [Parameter()]
    [Alias("I")]
    [switch]$Install,

    [Parameter()]
    [Alias("L")]
    [ValidateSet("", "auto", "hu", "en")]
    [string]$Lang = "",

    [Parameter()]
    [Alias("V")]
    [switch]$Version,

    [Parameter()]
    [Alias("H")]
    [switch]$Help
)

# =====================================================================
# ESZKÖZ ÖNVERZIÓZÁSA (Antigravity frissíti a saját repó alapján)
# =====================================================================
$ToolName = "FireFlow"
$ToolVersion = "v1.3.0"

$ErrorActionPreference = "Stop"

# UTF-8 kódolás beállítása a konzolhoz
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {}

# Nyelvi konfigurációs fájl elérési útja / Language config file path
$ScriptDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
} elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
$LangConfigFile = Join-Path $ScriptDir ".fireflow-lang"

# Ha a felhasználó explicit megadta a -Lang paramétert / Handle explicit -Lang
$UserLang = $Lang
if ($PSBoundParameters.ContainsKey('Lang') -and -not [string]::IsNullOrWhiteSpace($UserLang)) {
    if ($UserLang -eq "auto") {
        if (Test-Path $LangConfigFile) {
            Remove-Item $LangConfigFile -Force -ErrorAction SilentlyContinue
        }
    } elseif ($UserLang -eq "hu" -or $UserLang -eq "en") {
        Set-Content -Path $LangConfigFile -Value $UserLang -Encoding UTF8 -NoNewline
    }
}

# Korábban elmentett nyelv beolvasása / Read saved language preference
$SavedLang = ""
if ($UserLang -ne "auto" -and (Test-Path $LangConfigFile)) {
    $SavedLang = (Get-Content $LangConfigFile -Raw -ErrorAction SilentlyContinue).Trim()
}

# Aktív nyelv meghatározása / Determine active language
$ActiveLang = if ($UserLang -eq "hu" -or $UserLang -eq "en") {
    $UserLang
} elseif ($SavedLang -eq "hu" -or $SavedLang -eq "en") {
    $SavedLang
} else {
    if ((Get-UICulture).TwoLetterISOLanguageName -eq "hu") { "hu" } else { "en" }
}

# =====================================================================
# LOKALIZÁCIÓ / LOCALIZATION DICTIONARY
# =====================================================================
$LangKey = $ActiveLang
try { (Get-Variable Lang -Scope Script -ErrorAction SilentlyContinue).Attributes.Clear() } catch {}

$Script:Lang = @{
    hu = @{
        VersionOutput        = "$ToolName CLI - Verzió: $ToolVersion"
        InstallUpdated       = "[$ToolName] A globális parancs sikeresen frissítve a PowerShell profilodban!"
        InstallRegistered    = "[$ToolName] A globális parancs sikeresen regisztrálva a PowerShell profilodban!"
        ProfileFile          = "Profil fájl: {0}"
        InstallSuccessDesc   = "Mostantól bármely Firebase projekt könyvtárából futtatható a 'fireflow' parancs."
        InstallReload        = "Azonnali használathoz töltsd újra a profilodat vagy nyiss új terminált:"
        LangSetAuto          = "Alapértelmezett nyelv visszaállítva: Automatikus (rendszernyelv)."
        LangSetHu            = "Alapértelmezett nyelv beállítva: Magyar (mentve)."
        LangSetEn            = "Alapértelmezett nyelv beállítva: Angol (mentve)."
        FailPrefix           = "[$ToolName HIBA]: {0}"
        ErrPreviewPromote    = "A -Preview (-P) és -Promote (-PR) kapcsolók nem használhatók egyszerre!"
        ErrNotGitRepo        = "Ez a mappa nem egy Git repository."
        ErrFirebaseJson      = "A firebase.json nem található a projekt gyökerében."
        ErrGitNotFound       = "A 'git' parancs nem található."
        ErrFirebaseNotFound  = "A Firebase CLI ('firebase') nem található."
        ErrInvalidBaseVer    = "Érvénytelen alapverzió formátum: {0}"
        ErrNoModifiedFiles   = "Nincs módosított fájl a munkakönyvtárban. A deploy leállt. (Súgó: fireflow -h)"
        ErrPromoteDirty      = "A 'promote' (-PR) mód tiszta munkakönyvtárat igényel. Előbb commitold vagy stasheld a változásokat!"
        DirtyTreeError       = "HIBA: Nem commitolt modositasok vannak a munkakonyvtarban! Kerek egy 'fireflow -P' futtatast, vagy tedd felre a modositasokat (git stash) a Promote elott."
        PromptCommitMsg      = "Add meg a commit üzenetet"
        ErrEmptyCommitMsg    = "A commit üzenet nem lehet üres!"
        PlanTitle            = "KIADÁSI TERV ({0})"
        PlanProjectRoot      = "Projekt gyökér:    {0}"
        PlanCurrentBranch    = "Jelenlegi Git ág:  {0}"
        PlanTargetBranch     = "Cél Git ág:        {0} (Automatikus váltás/létrehozás)"
        PlanMergeBranch      = "Beolvasztandó ág:  {0} -> {1}"
        PlanBaseVer          = "Bázis verzió:      {0}"
        PlanNewVer           = "Új verzió (Tag):   {0} ({1})"
        PlanFirebaseTargets  = "Firebase célok:    {0}"
        PlanPreviewChannel   = "Preview csatorna:  {0}"
        PlanCommitMsg        = "Commit üzenet:     {0}"
        PlanHtmlFiles        = "Verziózandó HTML fájlok (__VERSION__ -> {0}):"
        PlanNoPlaceholder    = "FIGYELEM: Nem található '__VERSION__' placeholder egyetlen HTML fájlban sem!"
        PlanModifiedFiles    = "Módosított / Commitra váró fájlok (ellenőrizd, nincs-e köztük szemét!):"
        WarnNestedBranch     = "FIGYELEM: Nem a főágon ({0}), hanem a(z) '{1}' ágon állsz! Az új '{2}' ág ebből fog elágazni (vagy ide vált át), így örökölni fogja annak eddigi commitjait."
        PromptNestedConfirm  = "Biztosan elágaztatod a(z) '{0}' preview ágat a(z) '{1}' ágból a főág ({2}) helyett? [I/N]"
        PromptConfirm        = "Elindítod a folyamatot ezekkel a beállításokkal? [I/N]"
        UserCancelled        = "Folyamat megszakítva a felhasználó által."
        SwitchingPreview     = "`nÁtváltás a preview ágra: {0}..."
        ErrSwitchBranch      = "Nem sikerült átváltani a(z) {0} ágra."
        SwitchingPromote     = "`nÁtváltás a főágra ({0}) és '{1}' beolvasztása..."
        ErrMergeFailed       = "A Git merge ütközés vagy hiba miatt sikertelen. Oldd fel a konfliktusokat!"
        DeployStart          = "`nFirebase deploy indítása..."
        DeployBackend        = "Háttérszolgáltatások frissítése (--only {0})..."
        ErrBackendDeploy     = "A háttérszolgáltatások deploy-a sikertelen!"
        DeployHosting        = "Hosting feltöltése a(z) '{0}' preview csatornára..."
        ErrPreviewDeploy     = "A Firebase preview channel deploy sikertelen!"
        ErrLiveDeploy        = "A Firebase éles deploy sikertelen!"
        RestoringHtml        = "`nForrás HTML fájlok (__VERSION__ placeholder) visszaállítása..."
        GitOpsStart          = "`nGit verziókezelési műveletek végrehajtása..."
        ErrGitAdd            = "A 'git add -A' művelet sikertelen."
        ErrGitCommit         = "A Git commit sikertelen."
        ErrGitTag            = "A Git tag ({0}) létrehozása sikertelen."
        PushingRemote        = "Feltöltés a távoli repository-ba (origin/{0} + {1})..."
        ErrPushBranch        = "A Git branch push sikertelen."
        ErrPushTag           = "A Git tag push sikertelen."
        CleanupPrompt        = "Szeretnéd törölni a beolvasztott preview ágat és a Firebase csatornát? (i/n): "
        DelLocalBranch       = "Helyi Git ág törlése: preview/{0}..."
        DelRemoteBranch      = "Távoli Git ág törlése: preview/{0}..."
        DelFbChannel         = "Firebase preview csatorna törlése: {0}..."
        UrlCopied            = "A Preview URL a vágólapra másolva!"
        SuccessTitle         = "SIKERES FOLYAMAT!"
        SuccessMode          = "Mód:          {0}"
        SuccessBranch        = "Aktív ág:     {0}"
        SuccessTag           = "Kiadott tag:  {0}"
        SuccessSynced        = "Minden változás élesítve és szinkronizálva a GitHub-on!"
    }
    en = @{
        VersionOutput        = "$ToolName CLI - Version: $ToolVersion"
        InstallUpdated       = "[$ToolName] Global command successfully updated in your PowerShell profile!"
        InstallRegistered    = "[$ToolName] Global command successfully registered in your PowerShell profile!"
        ProfileFile          = "Profile file: {0}"
        InstallSuccessDesc   = "You can now run 'fireflow' from any Firebase project directory."
        InstallReload        = "To use it immediately, reload your profile or open a new terminal:"
        LangSetAuto          = "Default language reset to: Auto (system culture)."
        LangSetHu            = "Default language set to: Hungarian (saved)."
        LangSetEn            = "Default language set to: English (saved)."
        FailPrefix           = "[$ToolName ERROR]: {0}"
        ErrPreviewPromote    = "The -Preview (-P) and -Promote (-PR) switches cannot be used together!"
        ErrNotGitRepo        = "This directory is not a Git repository."
        ErrFirebaseJson      = "firebase.json was not found in the project root."
        ErrGitNotFound       = "The 'git' command was not found."
        ErrFirebaseNotFound  = "The Firebase CLI ('firebase') was not found."
        ErrInvalidBaseVer    = "Invalid base version format: {0}"
        ErrNoModifiedFiles   = "No modified files in working directory. Deploy aborted. (Help: fireflow -h)"
        ErrPromoteDirty      = "The 'promote' (-PR) mode requires a clean working directory. Commit or stash your changes first!"
        DirtyTreeError       = "ERROR: Uncommitted changes detected in the working tree! Please commit them (e.g., 'fireflow -P') or stash them before running Promote."
        PromptCommitMsg      = "Enter commit message"
        ErrEmptyCommitMsg    = "Commit message cannot be empty!"
        PlanTitle            = "RELEASE PLAN ({0})"
        PlanProjectRoot      = "Project root:      {0}"
        PlanCurrentBranch    = "Current branch:    {0}"
        PlanTargetBranch     = "Target branch:     {0} (Auto switch/create)"
        PlanMergeBranch      = "Merging branch:    {0} -> {1}"
        PlanBaseVer          = "Base version:      {0}"
        PlanNewVer           = "New version (Tag): {0} ({1})"
        PlanFirebaseTargets  = "Firebase targets:  {0}"
        PlanPreviewChannel   = "Preview channel:   {0}"
        PlanCommitMsg        = "Commit message:    {0}"
        PlanHtmlFiles        = "HTML files to version (__VERSION__ -> {0}):"
        PlanNoPlaceholder    = "WARNING: No '__VERSION__' placeholder found in any HTML file!"
        PlanModifiedFiles    = "Modified / Staged files (verify no unwanted files are included):"
        WarnNestedBranch     = "WARNING: You are currently on '{1}' instead of the main branch ({0})! The target branch '{2}' will branch off from here, inheriting its commits."
        PromptNestedConfirm  = "Are you sure you want to branch '{0}' off of '{1}' instead of the main branch ({2})? [Y/N]"
        PromptConfirm        = "Proceed with these settings? [Y/N]"
        UserCancelled        = "Operation cancelled by user."
        SwitchingPreview     = "`nSwitching to preview branch: {0}..."
        ErrSwitchBranch      = "Failed to switch to branch '{0}'."
        SwitchingPromote     = "`nSwitching to main branch ({0}) and merging '{1}'..."
        ErrMergeFailed       = "Git merge failed due to conflicts or errors. Resolve conflicts and retry!"
        DeployStart          = "`nStarting Firebase deploy..."
        DeployBackend        = "Updating backend services (--only {0})..."
        ErrBackendDeploy     = "Deployment of backend services failed!"
        DeployHosting        = "Deploying hosting to preview channel '{0}'..."
        ErrPreviewDeploy     = "Firebase preview channel deploy failed!"
        ErrLiveDeploy        = "Firebase live deploy failed!"
        RestoringHtml        = "`nRestoring source HTML files (__VERSION__ placeholder)..."
        GitOpsStart          = "`nExecuting Git version control operations..."
        ErrGitAdd            = "'git add -A' command failed."
        ErrGitCommit         = "Git commit failed."
        ErrGitTag            = "Failed to create Git tag ({0})."
        PushingRemote        = "Pushing to remote repository (origin/{0} + {1})..."
        ErrPushBranch        = "Git branch push failed."
        ErrPushTag           = "Git tag push failed."
        CleanupPrompt        = "Do you want to delete the merged preview branch and Firebase channel? (y/n): "
        DelLocalBranch       = "Deleting local Git branch: preview/{0}..."
        DelRemoteBranch      = "Deleting remote Git branch: preview/{0}..."
        DelFbChannel         = "Deleting Firebase preview channel: {0}..."
        UrlCopied            = "Preview URL copied to clipboard!"
        SuccessTitle         = "RELEASE SUCCESSFUL!"
        SuccessMode          = "Mode:          {0}"
        SuccessBranch        = "Active branch: {0}"
        SuccessTag           = "Released tag:  {0}"
        SuccessSynced        = "All changes deployed and synchronized with GitHub!"
    }
}
$Msg = $Script:Lang[$ActiveLang]

# Önálló nyelvváltás kezelése / Handle standalone -Lang switch
if ($PSBoundParameters.Count -eq 1 -and $PSBoundParameters.ContainsKey('Lang')) {
    if ($UserLang -eq "auto") {
        Write-Host ""
        Write-Host $Msg.LangSetAuto -ForegroundColor Green
        Write-Host ""
    } elseif ($UserLang -eq "hu") {
        Write-Host ""
        Write-Host $Msg.LangSetHu -ForegroundColor Green
        Write-Host ""
    } elseif ($UserLang -eq "en") {
        Write-Host ""
        Write-Host $Msg.LangSetEn -ForegroundColor Green
        Write-Host ""
    }
    exit 0
}

function Show-Help {
    if ($ActiveLang -eq "hu") {
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
        Write-Host "  -C      <csatorna>      Preview csatorna és Git ág neve (alap: 'preview', preview/* ágon automatikus)"
        Write-Host "  -T      <target>        Firebase Hosting target neve (multi-site projektekhez)"
        Write-Host "  -O      <komponensek>   Deploy szűrése (alap: 'hosting', pl. 'firestore:rules,functions')"
        Write-Host "  -B      <ág>            Fő Git ág neve (alapértelmezett: 'main', vagy 'master')"
        Write-Host "  -S,  -SkipHostingSync   HTML verziószinkron (automatikus hosting deploy) kihagyása"
        Write-Host "  -CL, -Cleanup           Promote után a preview ág és Firebase csatorna törlése"
        Write-Host "  -Y,  -Yes               Interaktív [I/N] jóváhagyás átugrása (azonnali futtatás)"
        Write-Host "  -I,  -Install           Globális parancs ('fireflow') regisztrálása a PowerShell profilban"
        Write-Host "  -L,  -Lang <hu|en|auto> Megjelenítési nyelv mentése (alapértelmezett: 'auto')"
        Write-Host "  -V,  -Version           Kiírja a $ToolName aktuális verziószámát"
        Write-Host "  -H,  -Help              Megjeleníti ezt a súgót"
        Write-Host ""
        Write-Host "GLOBÁLIS HASZNÁLAT:" -ForegroundColor Yellow
        Write-Host "  A 'fireflow -Install' futtatása után a parancs bármely projekt könyvtárából elérhető."
        Write-Host "  A 'fireflow -Lang en' önmagában futtatva elmenti az alapértelmezett nyelvet."
        Write-Host ""
        Write-Host "GYAKORLATI PÉLDÁK (PUSKÁZÓ):" -ForegroundColor Yellow
        Write-Host "  1. Gyors éles (patch) kiadás:" -ForegroundColor Cyan
        Write-Host "     fireflow `"Hibajavítás a főoldalon`""
        Write-Host ""
        Write-Host "  2. Éles (minor) kiadás egy adott hosting targetre:" -ForegroundColor Cyan
        Write-Host "     fireflow `"Új modul`" minor -T app"
        Write-Host ""
        Write-Host "  3. Csak Firestore szabályok frissítése (HTML verziószinkronnal együtt):" -ForegroundColor Cyan
        Write-Host "     fireflow `"Szabályok szigorítása`" -O firestore:rules"
        Write-Host ""
        Write-Host "  4. Fejlesztés küldése Preview csatornára (és 'preview/teszt' Git ágra):" -ForegroundColor Cyan
        Write-Host "     fireflow `"Új naptár teszt`" -P -C teszt -T app"
        Write-Host ""
        Write-Host "  5. Letesztelt Preview ág beolvasztása (merge) és élesítése:" -ForegroundColor Cyan
        Write-Host "     fireflow -PR -C teszt -T app"
        Write-Host ""
        Write-Host "  6. További teszt kiadás egy már aktív preview ágon (automatikus csatornafelismerés):" -ForegroundColor Cyan
        Write-Host "     fireflow `"További javítások`" -P"
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "=====================================================================" -ForegroundColor DarkCyan
        Write-Host "  $ToolName CLI ($ToolVersion) - Universal Firebase & Git Release Manager" -ForegroundColor Cyan
        Write-Host "=====================================================================" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "USAGE:" -ForegroundColor Yellow
        Write-Host "  fireflow [CommitMessage] [ReleaseType] [Switches...]"
        Write-Host "  (Or: .\fireflow.ps1 [CommitMessage] [ReleaseType] [Switches...])"
        Write-Host ""
        Write-Host "QUICK MODE SWITCHES:" -ForegroundColor Yellow
        Write-Host "  (default)               Production (live) release on the main branch"
        Write-Host "  -P,  -Preview           Test release to Firebase Preview Channel and dedicated Git branch"
        Write-Host "  -PR, -Promote           Merge preview branch into main and release to production"
        Write-Host ""
        Write-Host "PARAMETERS & SHORTCUTS:" -ForegroundColor Yellow
        Write-Host "  -CM     <text>          Commit message (1st positional parameter, -CM can be omitted)"
        Write-Host "  -R      <type>          Version increment: patch (default), minor, major (2nd positional)"
        Write-Host "  -M      <mode>          Explicit mode specification: live, preview, promote"
        Write-Host "  -C      <channel>       Preview channel and Git branch name (default: 'preview', auto on preview/*)"
        Write-Host "  -T      <target>        Firebase Hosting target name (for multi-site projects)"
        Write-Host "  -O      <components>    Deploy target filter (default: 'hosting', e.g. 'firestore:rules,functions')"
        Write-Host "  -B      <branch>        Main Git branch name (default: 'main' or 'master')"
        Write-Host "  -S,  -SkipHostingSync   Skip HTML version sync (automatic hosting deploy)"
        Write-Host "  -CL, -Cleanup           Delete preview branch and Firebase channel after promote"
        Write-Host "  -Y,  -Yes               Skip interactive confirmation [Y/N] (non-interactive run)"
        Write-Host "  -I,  -Install           Register global 'fireflow' command in PowerShell profile"
        Write-Host "  -L,  -Lang <hu|en|auto> Save display language preference (default: 'auto')"
        Write-Host "  -V,  -Version           Print current $ToolName version"
        Write-Host "  -H,  -Help              Display this help message"
        Write-Host ""
        Write-Host "GLOBAL USAGE:" -ForegroundColor Yellow
        Write-Host "  After running 'fireflow -Install', the command is available from any project folder."
        Write-Host "  Running 'fireflow -Lang en' standalone saves the default language preference."
        Write-Host ""
        Write-Host "PRACTICAL EXAMPLES (CHEAT SHEET):" -ForegroundColor Yellow
        Write-Host "  1. Quick production (patch) release:" -ForegroundColor Cyan
        Write-Host "     fireflow `"Bugfix on main page`""
        Write-Host ""
        Write-Host "  2. Production (minor) release to a specific hosting target:" -ForegroundColor Cyan
        Write-Host "     fireflow `"New feature module`" minor -T app"
        Write-Host ""
        Write-Host "  3. Update Firestore rules only (with HTML version sync):" -ForegroundColor Cyan
        Write-Host "     fireflow `"Strict security rules`" -O firestore:rules"
        Write-Host ""
        Write-Host "  4. Push changes to Preview Channel (and 'preview/test' Git branch):" -ForegroundColor Cyan
        Write-Host "     fireflow `"New calendar test`" -P -C test -T app"
        Write-Host ""
        Write-Host "  5. Merge tested preview branch (promote) and deploy live:" -ForegroundColor Cyan
        Write-Host "     fireflow -PR -C test -T app"
        Write-Host ""
        Write-Host "  6. Further test release on an active preview branch (auto channel detection):" -ForegroundColor Cyan
        Write-Host "     fireflow `"Additional fixes`" -P"
        Write-Host ""
    }
}

if ($Help -or $CommitMessage -in @("-h", "-Help", "--help", "-?", "/?", "-H", "-help")) {
    Show-Help
    exit 0
}

if ($Version -or $CommitMessage -in @("-v", "-Version", "--version", "-V", "-version")) {
    Write-Host $Msg.VersionOutput -ForegroundColor Cyan
    exit 0
}

if ($Install -or $CommitMessage -in @("-i", "-Install", "-I", "-install")) {
    $Install = $true
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

    $FunctionDef = "`r`n# FireFlow CLI Global Function`r`nfunction fireflow { `$a = @(`$args | ForEach-Object { if (`$_ -eq '-?') { '-h' } else { `$_ } }); & `"$ScriptFullPath`" @a }`r`n"

    if ($ProfileContent -match 'function\s+fireflow\b') {
        $lines = $ProfileContent -split '\r?\n'
        $filtered = @($lines | Where-Object { $_ -notmatch '^\s*#\s*FireFlow CLI Global Function' -and $_ -notmatch '^\s*function\s+fireflow\b' })
        $NewProfileContent = ($filtered -join "`r`n").TrimEnd() + $FunctionDef
        Set-Content -Path $ProfilePath -Value $NewProfileContent -Encoding UTF8
        Write-Host ""
        Write-Host $Msg.InstallUpdated -ForegroundColor Green
    } else {
        Add-Content -Path $ProfilePath -Value $FunctionDef -Encoding UTF8
        Write-Host ""
        Write-Host $Msg.InstallRegistered -ForegroundColor Green
    }

    Write-Host ($Msg.ProfileFile -f $ProfilePath) -ForegroundColor DarkCyan
    Write-Host $Msg.InstallSuccessDesc -ForegroundColor Green
    Write-Host $Msg.InstallReload -ForegroundColor Yellow
    Write-Host "  . `$PROFILE" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

function Fail($Message) {
    Write-Host ""
    Write-Host ($Msg.FailPrefix -f $Message) -ForegroundColor Red
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
    Fail $Msg.ErrPreviewPromote
}
if ($Preview) { $Mode = "preview" }
if ($Promote) {
    $gitStatus = git status --porcelain
    if (![string]::IsNullOrWhiteSpace($gitStatus)) {
        Write-Host "`n$($Script:Lang[$LangKey].DirtyTreeError)`n" -ForegroundColor Red
        exit 1
    }
    $Mode = "promote"
}
elseif ($Mode -eq "promote") {
    $gitStatus = git status --porcelain
    if (![string]::IsNullOrWhiteSpace($gitStatus)) {
        Write-Host "`n$($Script:Lang[$LangKey].DirtyTreeError)`n" -ForegroundColor Red
        exit 1
    }
}

# 1. Alapvető környezet ellenőrzése
$ProjectRoot = (Get-Location).Path

if (-not (Test-Path ".\.git")) { Fail $Msg.ErrNotGitRepo }
if (-not (Test-Path ".\firebase.json")) { Fail $Msg.ErrFirebaseJson }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail $Msg.ErrGitNotFound }
$FirebaseCmd = if (Get-Command firebase -ErrorAction SilentlyContinue) { "firebase" } 
               elseif (Get-Command firebase.cmd -ErrorAction SilentlyContinue) { "firebase.cmd" } 
               else { Fail $Msg.ErrFirebaseNotFound }

# 2. Aktuális Git ág és státusz lekérdezése
$CurrentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
$GitStatus = @(git status --porcelain)

# Ha a megadott MainBranch (pl. main) nem létezik, de van master, használjuk azt
$branchCheck = @(git branch --list $MainBranch)
if ($branchCheck.Count -eq 0 -and @(git branch --list "master").Count -gt 0) {
    $MainBranch = "master"
}
$ResolvedMainBranch = $MainBranch
$MainBranchName = $MainBranch

# Intelligens csatornafelismerés: ha nem adtak meg -Channel paramétert és egy preview/ ágon állunk
if (-not $PSBoundParameters.ContainsKey('Channel') -and $CurrentBranch.StartsWith("preview/")) {
    $Channel = $CurrentBranch.Substring("preview/".Length)
}

# 3. Legutóbbi stabil (vX.Y.Z) verzió megkeresése
$stableTags = @(git tag --list "v[0-9]*.[0-9]*.[0-9]*" --sort=-v:refname | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
$baseVersion = if ($stableTags.Count -gt 0) { $stableTags[0] } else { "v0.1.0" }

if ($baseVersion -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
    Fail ($Msg.ErrInvalidBaseVer -f $baseVersion)
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
    $TargetBranch = "preview/$safeChannel"
    
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
            $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
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
    Fail $Msg.ErrNoModifiedFiles
}

if ($Mode -eq "promote" -and $GitStatus.Count -gt 0) {
    Fail $Msg.ErrPromoteDirty
}

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    if ($Mode -eq "promote") {
        $CommitMessage = "Release $NewVersion (Promoted from $SourceBranch)"
    } else {
        $CommitMessage = Read-Host $Msg.PromptCommitMsg
    }
}
if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    Fail $Msg.ErrEmptyCommitMsg
}

# 7. Összegzés és Felhasználói Jóváhagyás (Interaktív Fék)
Write-Header ($Msg.PlanTitle -f $Mode.ToUpper())
Write-Host ($Msg.PlanProjectRoot -f $ProjectRoot)
Write-Host ($Msg.PlanCurrentBranch -f $CurrentBranch)
if ($TargetBranch -ne $CurrentBranch) {
    Write-Host ($Msg.PlanTargetBranch -f $TargetBranch) -ForegroundColor Yellow
}
if ($Mode -eq "promote") {
    Write-Host ($Msg.PlanMergeBranch -f $SourceBranch, $MainBranch) -ForegroundColor Magenta
}
Write-Host ($Msg.PlanBaseVer -f $baseVersion)
Write-Host ($Msg.PlanNewVer -f $NewVersion, $ReleaseType) -ForegroundColor Green
Write-Host ($Msg.PlanFirebaseTargets -f $FinalOnlyParam)
if ($Mode -eq "preview") {
    Write-Host ($Msg.PlanPreviewChannel -f $Channel) -ForegroundColor Cyan
}
Write-Host ($Msg.PlanCommitMsg -f $CommitMessage)
Write-Host ""

if ($VersionFiles.Count -gt 0) {
    Write-Host ($Msg.PlanHtmlFiles -f $NewVersion) -ForegroundColor Cyan
    foreach ($vf in $VersionFiles) {
        $rel = $vf.Substring($ProjectRoot.Length + 1)
        Write-Host "  [HTML] $rel"
    }
} else {
    Write-Host $Msg.PlanNoPlaceholder -ForegroundColor Yellow
}

if ($GitStatus.Count -gt 0) {
    Write-Host ""
    Write-Host $Msg.PlanModifiedFiles -ForegroundColor Yellow
    foreach ($line in $GitStatus) {
        Write-Host "  $line"
    }
}

# Nem-főági elágazás (Nested Fork) ellenőrzése és megerősítése
if ($Mode -eq "preview" -and $CurrentBranch -ne $TargetBranch -and $CurrentBranch -ne $ResolvedMainBranch) {
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Yellow
    Write-Host ($Msg.WarnNestedBranch -f $ResolvedMainBranch, $CurrentBranch, $TargetBranch) -ForegroundColor Yellow
    Write-Host "=====================================================================" -ForegroundColor Yellow
    Write-Host ""

    if (-not $Yes) {
        $nestedConfirm = Read-Host ($Msg.PromptNestedConfirm -f $TargetBranch, $CurrentBranch, $ResolvedMainBranch)
        if ($nestedConfirm -notmatch '^[iIyY]$') {
            Write-Host $Msg.UserCancelled -ForegroundColor Yellow
            exit 0
        }
    }
}

Write-Host ""
if (-not $Yes) {
    $confirm = Read-Host $Msg.PromptConfirm
    if ($confirm -notmatch '^[iIyY]$') {
        Write-Host $Msg.UserCancelled -ForegroundColor Yellow
        exit 0
    }
}

# =====================================================================
# 8. VÉGREHAJTÁS: GIT ELŐKÉSZÍTÉS ÉS HELYBEN TÖRTÉNŐ DEPLOY
# =====================================================================

# Branch váltás vagy Merge kezelése
if ($Mode -eq "preview" -and $CurrentBranch -ne $TargetBranch) {
    Write-Host ($Msg.SwitchingPreview -f $TargetBranch) -ForegroundColor Cyan
    $branchExists = @(git branch --list $TargetBranch)
    if ($branchExists.Count -gt 0) {
        git checkout $TargetBranch
    } else {
        git checkout -b $TargetBranch
    }
    if ($LASTEXITCODE -ne 0) { Fail ($Msg.ErrSwitchBranch -f $TargetBranch) }
}
elseif ($Mode -eq "promote") {
    Write-Host ($Msg.SwitchingPromote -f $MainBranch, $SourceBranch) -ForegroundColor Cyan
    if ($CurrentBranch -ne $MainBranch) {
        git checkout $MainBranch
        if ($LASTEXITCODE -ne 0) { Fail ($Msg.ErrSwitchBranch -f $MainBranch) }
    }
    git pull origin $MainBranch
    git merge $SourceBranch --no-ff -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrMergeFailed }
}

# Eredeti HTML tartalmak mentése a memóriába és bájt-pontos helyettesítés
$BackupHtmlContent = @{}
$PreviewUrl = $null
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
    foreach ($vf in $VersionFiles) {
        $rawContent = [System.IO.File]::ReadAllText($vf, [System.Text.Encoding]::UTF8)
        $BackupHtmlContent[$vf] = $rawContent
        $updatedContent = $rawContent.Replace("__VERSION__", $NewVersion)
        [System.IO.File]::WriteAllText($vf, $updatedContent, $Utf8NoBom)
    }

    # FIREBASE DEPLOY FUTTATÁSA
    Write-Host $Msg.DeployStart -ForegroundColor Cyan
    
    if ($Mode -eq "preview") {
        # 1. Nem-hosting komponensek deployolása (ha van ilyen megadva)
        $nonHostingTargets = @($DeployOnlyList | Where-Object { $_ -ne "hosting" -and -not $_.StartsWith("hosting:") })
        if ($nonHostingTargets.Count -gt 0) {
            $nhParam = $nonHostingTargets -join ","
            Write-Host ($Msg.DeployBackend -f $nhParam) -ForegroundColor DarkCyan
            & $FirebaseCmd deploy --only $nhParam
            if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrBackendDeploy }
        }

        # 2. Hosting deploy a Preview Channelre
        $hasHostingTarget = @($DeployOnlyList | Where-Object { $_ -eq "hosting" -or $_.StartsWith("hosting:") }).Count -gt 0
        if ($hasHostingTarget) {
            Write-Host ($Msg.DeployHosting -f $Channel) -ForegroundColor DarkCyan
            $ChannelName = $Channel
            if ([string]::IsNullOrWhiteSpace($Target)) {
                firebase hosting:channel:deploy $ChannelName 2>&1 | Tee-Object -Variable fbTeeVar
            } else {
                firebase hosting:channel:deploy $ChannelName --only $Target 2>&1 | Tee-Object -Variable fbTeeVar
            }
            if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrPreviewDeploy }

            $PreviewUrl = $null
            $urlLine = $fbTeeVar | Where-Object { $_ -match 'https://[^\s]+\.web\.app' -or $_ -match 'https://[^\s]+\.firebaseapp\.com' } | Select-Object -Last 1
            if ($urlLine -match '(https://[^\s]+)') {
                $PreviewUrl = $matches[1]
            }
        }
    }
    else {
        # LIVE és PROMOTE mód: teljes éles deploy
        & $FirebaseCmd deploy --only $FinalOnlyParam
        if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrLiveDeploy }
    }
}
finally {
    # GARANTÁLT VISSZAÁLLÍTÁS: A __VERSION__ placeholder bájt-pontos visszaírása a forrásfájlokba
    if ($BackupHtmlContent.Count -gt 0) {
        Write-Host $Msg.RestoringHtml -ForegroundColor DarkGray
        foreach ($vf in $BackupHtmlContent.Keys) {
            [System.IO.File]::WriteAllText($vf, $BackupHtmlContent[$vf], $Utf8NoBom)
        }
    }
}

# =====================================================================
# 9. GIT COMMIT, TAG ÉS PUSH (Csak sikeres deploy után!)
# =====================================================================
Write-Host $Msg.GitOpsStart -ForegroundColor Cyan

if ($Mode -ne "promote") {
    git add -A
    if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrGitAdd }

    git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrGitCommit }
}

git tag -a $NewVersion -m $CommitMessage
if ($LASTEXITCODE -ne 0) { Fail ($Msg.ErrGitTag -f $NewVersion) }

$ActiveBranch = (git rev-parse --abbrev-ref HEAD).Trim()

Write-Host ($Msg.PushingRemote -f $ActiveBranch, $NewVersion) -ForegroundColor Cyan
git push -u origin $ActiveBranch
if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrPushBranch }

git push origin $NewVersion
if ($LASTEXITCODE -ne 0) { Fail $Msg.ErrPushTag }

if ($Mode -eq "promote" -or $Promote) {
    $ChannelName = if ($SourceBranch -and $SourceBranch.StartsWith("preview/")) {
        $SourceBranch.Substring("preview/".Length)
    } else {
        $Channel
    }
    $YesToAll = $Yes

    $doCleanup = $false
    if ($Cleanup -or $YesToAll) {
        $doCleanup = $true
    } else {
        $ans = Read-Host $Script:Lang[$LangKey].CleanupPrompt
        if ($ans -match '^[iIyY]') {
            $doCleanup = $true
        }
    }

    if ($doCleanup) {
        Write-Host ($Script:Lang[$LangKey].DelLocalBranch -f $ChannelName) -ForegroundColor Cyan
        cmd /c "echo n | git branch -d `"preview/$ChannelName`" 2>&1" | Out-Null
        
        Write-Host ($Script:Lang[$LangKey].DelRemoteBranch -f $ChannelName) -ForegroundColor Cyan
        cmd /c "echo n | git push origin --delete `"preview/$ChannelName`" 2>&1" | Out-Null
        
        Write-Host ($Script:Lang[$LangKey].DelFbChannel -f $ChannelName) -ForegroundColor Cyan
        firebase hosting:channel:delete $ChannelName --force

        # Cleanup empty Git tracking directories after lock releases
        Start-Sleep -Milliseconds 500
        $gitDirs = @(".git/refs/heads/preview", ".git/logs/refs/heads/preview", ".git/refs/remotes/origin/preview", ".git/logs/refs/remotes/origin/preview")
        foreach ($dir in $gitDirs) {
            if (Test-Path $dir) {
                $items = Get-ChildItem $dir -Force
                if ($items.Count -eq 0) { Remove-Item -Path $dir -Force -Recurse -ErrorAction SilentlyContinue }
            }
        }
    }
}

Write-Header $Msg.SuccessTitle
if ($PreviewUrl) {
    Write-Host "`nPreview URL: $PreviewUrl" -ForegroundColor Cyan
    Set-Clipboard -Value $PreviewUrl
    Write-Host $Script:Lang[$LangKey].UrlCopied -ForegroundColor Green
}
Write-Host ($Msg.SuccessMode -f $Mode.ToUpper()) -ForegroundColor Green
Write-Host ($Msg.SuccessBranch -f $ActiveBranch) -ForegroundColor Green
Write-Host ($Msg.SuccessTag -f $NewVersion) -ForegroundColor Green
Write-Host $Msg.SuccessSynced -ForegroundColor Green
Write-Host ""

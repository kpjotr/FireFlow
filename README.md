# FireFlow CLI

**Language / Nyelv:** [🇬🇧 English](#fireflow-cli-en) | [🇭🇺 Magyar](#fireflow-cli-hu)

---

<a id="fireflow-cli-en"></a>
# FireFlow CLI (English)

**Version:** `v1.2.1`  
**Release Date:** October 23, 2026  
**Type:** Universal Firebase Deploy, Git Branch & Version Management Tool (PowerShell)  
**License:** GNU GPLv3

---

## Overview

**FireFlow** (`fireflow.ps1`) is a single-file, project-agnostic CI/CD and release management command-line tool for Firebase-based web applications.

Its goal is to coordinate the deployment of **Firebase Hosting, Cloud Functions, Firestore Rules, and Storage** components (to either production or preview channels) with **Git version control** (branches, commits, tags) in a single concise command, while guaranteeing that the version number displayed in client HTML source files always matches the running Git version tag.

### Key Features
* **Short, one- or two-letter switches:** Minimal typing for daily workflows (`-P`, `-PR`, `-C`, `-T`, `-O`, `-I`, `-L`, `-h`).
* **Bilingual CLI with Persistent Preference:** Full English and Hungarian support (`-L en` / `-L hu` / `-L auto`). The chosen language is saved persistently in a local `.fireflow-lang` file for future runs. If not set, it automatically detects your OS culture.
* **Global CLI Installation (`-Install` / `-I`):** Register once in PowerShell `$PROFILE`, allowing execution simply via `fireflow` from any project directory without copying the script into each repository. Also handles `-?` gracefully without native PowerShell help interception.
* **In-Place Version Injection & Guaranteed Restoration:** Injects the current version tag directly into source HTML files replacing `__VERSION__` for the duration of the deployment, and restores the original placeholder immediately before Git commit inside a protected `finally` block.
* **Global Version Synchronization:** Updates the version displayed in HTML (and deploys hosting) even when deploying backend-only changes (e.g. `firestore:rules` or `functions`).
* **Multi-Site (Target) Support:** Automatically parses `firebase.json` and supports specific hosting targets.
* **Integrated Preview & Branch Workflow:** In preview mode (`-P`), automatically switches to a dedicated Git branch (`preview/<channel>`), increments test build numbers (`vX.Y.Z-preview.N`), and publishes to the Firebase Preview Channel.
* **One-Step Promotion & Merge:** In promote mode (`-PR`), merges the tested preview branch into `main`, strips the preview tag to a clean release version (`vX.Y.Z`), and deploys directly to production.
* **Built-in Interactive Terminal Help:** Run `fireflow -h` or `fireflow -?` anytime to display a colorful quick reference cheat sheet.

---

## Prerequisites and Setup

1. **Environment:** Windows PowerShell 5.1+ or PowerShell Core (pwsh), installed and authenticated `git` and `firebase-tools` (Firebase CLI).
2. **Global Installation (Recommended):** Clone or download this repository to any directory on your machine, then run the one-time installer:
   ```powershell
   .\fireflow.ps1 -Install
   ```
   *(or shortly: `.\fireflow.ps1 -I`)*  
   This registers a global `fireflow` function in your PowerShell `$PROFILE`. After opening a new terminal (or running `. $PROFILE`), you **do not need to copy the script into each individual project repository**; simply invoke `fireflow` from any Firebase project root folder.  
   *(Alternatively, `fireflow.ps1` can still be copied directly into a project root and invoked locally as `.\fireflow.ps1`.)*
3. **HTML Preparation:** Place the `__VERSION__` placeholder text in your target HTML files (e.g., in `index.html` footer: `<span>Version: __VERSION__</span>`).
4. **Gitignore:** Ensure that your project's `.gitignore` properly ignores unwanted directories (`node_modules/`, `.firebase/`, etc.), as FireFlow stages modified project files (`git add -A`) after your interactive confirmation.

---

## Parameters and Aliases

PowerShell parameters and switches are case-insensitive (`-CM` = `-cm`, `-P` = `-p`).

| Shortcut (Alias) | Full parameter | Default | Description |
| :--- | :--- | :--- | :--- |
| **`-CM`** *(1st pos.)* | `-CommitMessage` | *(prompted)* | Git commit and tag message. As 1st positional argument, `-CM` can be omitted. |
| **`-R`** *(2nd pos.)* | `-ReleaseType` | `patch` | Version bump magnitude: `patch` (0.0.X), `minor` (0.X.0), `major` (X.0.0). |
| **`-P`** | `-Preview` | `false` | **Quick switch:** Switch to `preview` (test) mode. |
| **`-PR`** | `-Promote` | `false` | **Quick switch:** Switch to `promote` (merge and release) mode. |
| **`-M`** | `-Mode` | `live` | Explicit execution mode (`live`, `preview`, `promote`). |
| **`-C`** | `-Channel` | `preview` | Firebase Preview channel and test Git branch (`preview/<Channel>`) name. |
| **`-T`** | `-Target` | *(empty)* | Target hosting target name in multi-site Firebase setups. |
| **`-O`** | `-Only` | `hosting` | Comma-separated Firebase components (e.g. `firestore:rules,functions`). |
| **`-B`** | `-MainBranch` | `main` | Project main Git branch (automatically falls back to `master` if `main` does not exist). |
| **`-S`** | `-SkipHostingSync`| `false` | Disable automatic forced update of HTML version number (and hosting deploy). |
| **`-Y`** | `-Yes` | `false` | Skip interactive `[Y/N]` confirmation (for automated CI/CD runs). |
| **`-I`** | `-Install` | `false` | **Global Setup:** Registers the `fireflow` command in PowerShell `$PROFILE`. |
| **`-L`** | `-Lang` | `auto` | Language selection: `auto` (system culture), `hu` (Hungarian), `en` (English). Saves preference persistently for future runs (`-L auto` resets). |
| **`-V`** | `-Version` | `false` | Prints the FireFlow CLI version and exits. |
| **`-H`** | `-Help` | `false` | Displays the detailed command-line help cheat sheet and exits. |

---

## Detailed Execution Modes

### 1. `live` Mode (Default Production Release)
Intended for standard production releases. Finds the latest stable `vX.Y.Z` Git tag, calculates the next version (`patch`/`minor`/`major`), injects it into HTML files, deploys the specified Firebase components, restores the `__VERSION__` placeholder, and finally commits, tags, and pushes to the current branch.

### 2. `preview` Mode (`-P` switch)
Safe testing workflow before production release:
1. If currently on the main branch, automatically switches to (or creates) a dedicated Git branch: `preview/<Channel>`.
2. Calculates the next base version with an incrementing test build suffix: e.g. `v1.0.11-preview.1` (next run: `v1.0.11-preview.2`).
3. Replaces `__VERSION__` in HTML files with this preview version.
4. Deploys hosting directly to the specified Firebase Preview Channel (`firebase hosting:channel:deploy`), while deploying any other requested services (`-O`).
5. Restores the HTML placeholder, then commits, tags, and pushes to the `preview/<Channel>` branch.

### 3. `promote` Mode (`-PR` switch)
Once all tests succeed on the preview channel, this mode finalizes the production release:
1. Requires a clean working directory (all changes committed on the preview branch).
2. Switches to the main branch (`main`), pulls latest changes, and merges (`git merge --no-ff`) the preview branch.
3. Cleans the version string to a final release format (e.g. `v1.0.11-preview.2` becomes clean `v1.0.11`).
4. Performs a complete live Firebase deploy with the updated HTML version number, creates the final Git release tag, and pushes to `main`.

---

## Practical Examples (Cheat Sheet)

### One-Time Global Setup
```powershell
.\fireflow.ps1 -Install
```

### Help and Version Queries
*(Supports `-h`, `-Help`, and `-?` via global `fireflow`)*
```powershell
fireflow -h
fireflow -?
fireflow -v
```

### Persistent Language Switching
```powershell
# Set persistent default language to English
fireflow -Lang en

# Set persistent default language to Hungarian
fireflow -Lang hu

# Reset to automatic OS language detection
fireflow -Lang auto
```

### 1. Quick Production (Patch) Release
```powershell
fireflow "Bugfix on main page"
```

### 2. Production (Minor) Release to a Specific Hosting Target
```powershell
fireflow "New feature module" minor -T app
```

### 3. Update Firestore Rules Only (With HTML Version Sync)
```powershell
fireflow "Strict security rules" -O firestore:rules
```

### 4. Deploy to Preview Channel (and 'preview/test' Git branch)
```powershell
fireflow "New calendar test" -P -C test -T app
```

### 5. Merge Tested Preview Branch (Promote) and Deploy Live
```powershell
fireflow -PR -C test -T app
```

---

## Tool Self-Versioning
FireFlow automatically tracks its own release lifecycle using its own internal version variable `$ToolVersion` synchronized with its repository tags.

---

## License

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](LICENSE). See the `LICENSE` file for details.

---

<a id="fireflow-cli-hu"></a>
# FireFlow CLI (Magyar)

**Verzió:** `v1.2.1`  
**Kiadás dátuma:** 2026. október 23.  
**Típus:** Univerzális Firebase Deploy, Git Branch és Verziókezelő Eszköz (PowerShell)  
**Licenc:** GNU GPLv3

---

## Áttekintés

A **FireFlow** (`fireflow.ps1`) egy egyfájlos, projekttől független CI/CD és kiadáskezelő (release management) parancssori eszköz Firebase alapú webalkalmazásokhoz. 

Célja, hogy egyetlen rövid paranccsal összehangolja a **Firebase Hosting, Cloud Functions, Firestore Rules és Storage** komponensek éles vagy teszt (preview) telepítését a **Git verziókezeléssel** (branch-ek, commitok, tagek), miközben garantálja, hogy a böngészőben megjelenő HTML felületen mindig a ténylegesen futó Git verziószám látszódjon.

### Főbb képességek
* **Rövid, egy-két betűs kapcsolók:** Minimális gépelés a napi munkafolyamatok során (`-P`, `-PR`, `-C`, `-T`, `-O`, `-I`, `-L`, `-h`).
* **Kétnyelvű működés és tartós nyelvmentés:** Teljes angol és magyar támogatás (`-L en` / `-L hu` / `-L auto`). A választott nyelvet a script a helyi `.fireflow-lang` fájlban tartósan elmenti a jövőbeli futtatásokhoz. Ha nincs beállítva, automatikusan igazodik a rendszernyelvhez.
* **Globális CLI telepítés (`-Install` / `-I`):** Egyszeri beállítás a PowerShell `$PROFILE`-ban, amely lehetővé teszi a `fireflow` futtatását bármely könyvtárból a script repókba másolgatása nélkül. Kezeli a `-?` kapcsolót is a natív Get-Help felülbírálásával.
* **In-Place Verzió-injektálás és Visszaállítás:** Ideiglenes mappák másolgatása helyett közvetlenül a forrás HTML fájlokban cseréli le a `__VERSION__` helyőrzőt a deploy idejére, majd egy védett `finally` blokkban azonnal visszaállítja az eredeti állapotot a Git commit előtt.
* **Globális Verziószinkron:** Akkor is frissíti a HTML-ben látható verziószámot (és a hostingot), ha az adott körben csak háttérszolgáltatást (pl. `firestore:rules` vagy `functions`) módosítottál.
* **Multi-Site (Target) támogatás:** Automatikusan elemzi a `firebase.json` fájlt, és kezeli az egyedi hosting targeteket.
* **Integrált Preview és Branch munkafolyamat:** Teszteléskor (`-P`) automatikusan külön Git ágra vált (`preview/<csatorna>`), növeli a teszt build számát (`vX.Y.Z-preview.N`), és a Firebase Preview Channelre publikál.
* **Egygombos Promote és Merge:** A tesztelés végeztével (`-PR`) beolvasztja a preview ágat a főágba (`main`), lecsupaszítja a verziószámot véglegesre (`vX.Y.Z`), és élesíti a rendszert.
* **Beépített terminálos súgó:** A `fireflow -h` vagy `fireflow -?` parancs bármikor megjeleníti a színes puskázót magyar vagy angol nyelven.

---

## Előfeltételek és Globális Beállítás

1. **Környezet:** Windows PowerShell 5.1+ vagy PowerShell Core (pwsh), telepített és bejelentkezett `git` és `firebase-tools` (Firebase CLI).
2. **Globális telepítés (Ajánlott):** Klónozd ezt a tárolót egy tetszőleges mappába, majd futtasd az egyszeri globális telepítést:
   ```powershell
   .\fireflow.ps1 -Install
   ```
   *(vagy röviden: `.\fireflow.ps1 -I`)*  
   Ez automatikusan regisztrálja a `fireflow` függvényt a PowerShell `$PROFILE`-odban. A terminál újranyitása (vagy `. $PROFILE` futtatása) után a scriptet **nem szükséges külön bemásolni az egyes projektekbe** – közvetlenül a `fireflow` paranccsal futtatható bármely Firebase projekt könyvtárából.  
   *(Alternatívaként a `fireflow.ps1` fájl továbbra is közvetlenül bemásolható egy projekt gyökerébe, és helyileg futtatható a `.\fireflow.ps1` paranccsal.)*
3. **HTML Előkészítés:** A megjeleníteni kívánt `.html` fájlokban (pl. `index.html`) helyezd el a `__VERSION__` szöveget (például a láblécben: `<span>Verzió: __VERSION__</span>`).
4. **Gitignore:** Gondoskodj róla, hogy a projekted `.gitignore` fájlja megfelelően szűrje a nem kívánt fájlokat (`node_modules/`, `.firebase/`, stb.), mert a script a jóváhagyásod után minden módosítást (`git add -A`) verziózni fog.

---

## Paraméterek és Rövidítések (Aliasok)

A PowerShellben a kapcsolók nem kis- és nagybetű érzékenyek (`-CM` = `-cm`, `-P` = `-p`).

| Rövidítés (Alias) | Teljes paraméter | Alapértelmezett | Leírás |
| :--- | :--- | :--- | :--- |
| **`-CM`** *(1. poz.)* | `-CommitMessage` | *(bekéri)* | A Git commit és tag üzenete. Első paraméterként a `-CM` el is hagyható. |
| **`-R`** *(2. poz.)* | `-ReleaseType` | `patch` | Verzióléptetés mértéke: `patch` (0.0.X), `minor` (0.X.0), `major` (X.0.0). |
| **`-P`** | `-Preview` | `false` | **Gyorskapcsoló:** Átkapcsol `preview` (teszt) módba. |
| **`-PR`** | `-Promote` | `false` | **Gyorskapcsoló:** Átkapcsol `promote` (beolvasztás és élesítés) módba. |
| **`-M`** | `-Mode` | `live` | Működési mód explicit megadása (`live`, `preview`, `promote`). |
| **`-C`** | `-Channel` | `preview` | A Firebase Preview csatorna és a teszt Git ág (`preview/<Channel>`) neve. |
| **`-T`** | `-Target` | *(üres)* | Multi-site Firebase konfiguráció esetén a célzott hosting target neve. |
| **`-O`** | `-Only` | `hosting` | Vesszővel elválasztott Firebase komponensek (pl. `firestore:rules,functions`). |
| **`-B`** | `-MainBranch` | `main` | A projekt fő Git ága (automatikusan felismeri a `master`-t is). |
| **`-S`** | `-SkipHostingSync`| `false` | Kikapcsolja a HTML verziószám (és a hosting) automatikus kényszerített frissítését. |
| **`-Y`** | `-Yes` | `false` | Átugorja az interaktív `[I/N]` megerősítést (automatizált futtatáshoz). |
| **`-I`** | `-Install` | `false` | **Globális telepítés:** Regisztrálja a `fireflow` parancsot a PowerShell `$PROFILE`-ban. |
| **`-L`** | `-Lang` | `auto` | Megjelenítési nyelv: `auto` (rendszernyelv alapján), `hu` (magyar), `en` (angol). Tartósan elmenti a választást a jövőbeli futtatásokhoz (`-L auto` visszaállítja). |
| **`-V`** | `-Version` | `false` | Kiírja a FireFlow CLI eszköz saját verziószámát, majd kilép. |
| **`-H`** | `-Help` | `false` | Megjeleníti a részletes parancssori súgót és puskázót, majd kilép. |

---

## Működési Módok Részletesen

### 1. `live` mód (Alapértelmezett éles kiadás)
Közvetlen élesítésre szolgál. Megkeresi a legutóbbi stabil `vX.Y.Z` Git taget, növeli a verziót (`patch`/`minor`/`major`), beírja a HTML-be, élesíti a megadott Firebase komponenseket, visszaállítja a `__VERSION__` placeholdert, végül commitol, tagel és pushol az aktuális ágra.

### 2. `preview` mód (`-P` kapcsoló)
Biztonságos tesztelési munkafolyamat élesítés előtt:
1. Ha a főágon (`main`) állsz, automatikusan létrehoz (vagy átvált) egy `preview/<Channel>` nevű Git ágra.
2. Kiszámolja a következő verziót, és ellátja egy növekvő teszt-azonosítóval: pl. `v1.0.11-preview.1` (a következő futtatáskor `v1.0.11-preview.2`).
3. A HTML fájlokban lecseréli a `__VERSION__` placeholdert erre a preview verzióra.
4. A hostingot a megadott Firebase Preview Channelre (`firebase hosting:channel:deploy`) tölti fel, míg az esetleges egyéb komponenseket (`-O`) frissíti.
5. Visszaállítja a HTML placeholdert, majd commitol, tagel és pushol a `preview/<Channel>` Git ágra.

### 3. `promote` mód (`-PR` kapcsoló)
Amikor a preview csatornán minden teszt sikeres volt, ez a mód véglegesíti a kiadást:
1. Megköveteli a tiszta munkakönyvtárat (minden változás legyen már commitolva a preview ágon).
2. Átvált a főágra (`main`), frissíti azt (`git pull`), majd beolvasztja (`git merge --no-ff`) a preview ágat.
3. A verziószámot lecsupaszítja végleges formátumra (pl. a `v1.0.11-preview.2`-ből tiszta `v1.0.11` lesz).
4. Elvégzi a teljes éles Firebase deployt a frissített HTML verziószámmal, majd felteszi a végleges Git taget és pusholja a főágat.

---

## Gyakorlati Puskázó (Cheat Sheet)

### Egyszeri globális telepítés
```powershell
.\fireflow.ps1 -Install
```

### Súgó és verzió lekérdezése
*(Globális telepítés esetén a `-h`, `-Help` és `-?` is működik)*
```powershell
fireflow -h
fireflow -?
fireflow -v
```

### Alapértelmezett nyelv tartós beállítása
```powershell
# Nyelv tartós beállítása angolra
fireflow -Lang en

# Nyelv tartós beállítása magyarra
fireflow -Lang hu

# Visszaállítás az operációs rendszer nyelvéhez
fireflow -Lang auto
```

### 1. Gyors éles (patch) kiadás
```powershell
fireflow "Hibajavítás a főoldalon"
```

### 2. Éles (minor) kiadás egy adott hosting targetre
```powershell
fireflow "Új modul" minor -T app
```

### 3. Csak Firestore szabályok frissítése (HTML verziószinkronnal)
```powershell
fireflow "Szabályok szigorítása" -O firestore:rules
```

### 4. Fejlesztés küldése Preview csatornára
```powershell
fireflow "Új naptár teszt" -P -C teszt -T app
```

### 5. Letesztelt Preview ág beolvasztása (promote) és élesítése
```powershell
fireflow -PR -C teszt -T app
```

---

## Eszköz önverziózása
A FireFlow CLI belső verziókövető változóval (`$ToolVersion`) rendelkezik, amely szinkronban van a saját tárolójának Git tagjeivel.

---

## Licenc

Ez a projekt a [GNU General Public License v3.0 (GPLv3)](LICENSE) feltételei szerint van licencelve. Részletekért lásd a `LICENSE` fájlt.

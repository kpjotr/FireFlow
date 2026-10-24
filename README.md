# FireFlow CLI

**Language / Nyelv:** [🇬🇧 English](#fireflow-cli-en) | [🇭🇺 Magyar](#fireflow-cli-hu)

---

<a id="fireflow-cli-en"></a>
# FireFlow CLI (English)

**Version:** `v1.2.2`  
**Release Date:** October 24, 2026  
**Type:** Universal Firebase Deploy, Git Branch & Version Management Tool (PowerShell)  
**License:** GNU GPLv3

---

## Overview

**FireFlow** (`fireflow.ps1`) is a single-file, project-agnostic CI/CD and release management command-line tool for Firebase-based web applications.

Its goal is to coordinate the deployment of **Firebase Hosting, Cloud Functions, Firestore Rules, and Storage** components (to either production or preview channels) with **Git version control** (branches, commits, tags) in a single concise command, while guaranteeing that the version number displayed in client HTML source files always matches the running Git version tag.

### Key Features
* **Short, one- or two-letter switches:** Minimal typing for daily workflows (`-P`, `-PR`, `-C`, `-T`, `-O`, `-I`, `-L`, `-h`).
* **Smart Channel Auto-Detection:** When working on an active `preview/<channel>` branch, `-Channel` / `-C` is automatically resolved from the branch name for both preview deploys (`-P`) and promotions (`-PR`).
* **Nested Branch Safety Guard:** Alerts if creating a preview branch from a non-main branch (e.g., from an existing preview branch), preventing accidental chain branching without explicit confirmation.
* **Byte-Exact HTML Injection & Restoration:** Replaces `__VERSION__` in HTML files for deployment and restores the exact original byte stream in a protected `finally` block without altering line breaks or injecting unwanted UTF-8 BOM.
* **Bilingual CLI with Persistent Preference:** Full English and Hungarian support (`-L en` / `-L hu` / `-L auto`). The chosen language is saved persistently in a local `.fireflow-lang` file for future runs. If not set, it automatically detects your OS culture.
* **Global CLI Installation (`-Install` / `-I`):** Register once in PowerShell `$PROFILE`, allowing execution simply via `fireflow` from any project directory without copying the script into each repository. Also handles `-?` gracefully without native PowerShell help interception.
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
| **`-C`** | `-Channel` | `preview` | Firebase Preview channel and test Git branch (`preview/<Channel>`) name (auto-detected on `preview/*` branches). |
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
1. **Branch Resolution & Safety Guard:** If on the main branch, automatically creates or switches to `preview/<Channel>`. If already on a `preview/<channel>` branch and `-C` is omitted, it automatically detects the current channel. If you attempt to branch to a new channel from an existing non-main branch, FireFlow displays an explicit warning and requires confirmation to avoid accidental nested commits.
2. Calculates the next base version with an incrementing test build suffix: e.g. `v1.0.11-preview.1` (next run: `v1.0.11-preview.2`).
3. Replaces `__VERSION__` in HTML files with this preview version using byte-exact UTF-8.
4. Deploys hosting directly to the specified Firebase Preview Channel (`firebase hosting:channel:deploy`), while deploying any other requested services (`-O`).
5. Restores the HTML placeholder byte-for-byte, then commits, tags, and pushes to the `preview/<Channel>` branch.

### 3. `promote` Mode (`-PR` switch)
Once all tests succeed on the preview channel, this mode finalizes the production release:
1. Requires a clean working directory (all changes committed on the preview branch).
2. Automatically detects the preview channel if currently on `preview/<channel>` (or uses `-C`).
3. Switches to the main branch (`main`), pulls latest changes, and merges (`git merge --no-ff`) the preview branch.
4. Cleans the version string to a final release format (e.g. `v1.0.11-preview.2` becomes clean `v1.0.11`).
5. Performs a complete live Firebase deploy with the updated HTML version number, creates the final Git release tag, and pushes to `main`.

### 4. Nested Preview Branching (Multi-Level Forks)
In complex feature development, you might want to branch a secondary preview channel directly off an existing, active preview branch rather than `main` (for instance, starting `preview/feature-b` from `preview/feature-a`):

* **Safety Guard & Warning:** If you execute `fireflow "Start sub-feature" -P -C feature-b` while currently on `preview/feature-a`, FireFlow detects that you are branching from a non-main branch. It prints a highlighted yellow warning and prompts for explicit confirmation before proceeding:
  ```text
  WARNING: You are currently on 'preview/feature-a' instead of the main branch (main)!
  The target branch 'preview/feature-b' will branch off from here, inheriting its commits.
  Are you sure you want to branch 'preview/feature-b' off of 'preview/feature-a' instead of the main branch (main)? [Y/N]
  ```
* **Git History Inheritance & Versioning:** `preview/feature-b` branches off from the latest commit of `preview/feature-a`, inheriting all its commits and history. The build counter increments sequentially based on the shared base version: if `feature-a` has tags `v1.3.5-preview.1` and `v1.3.5-preview.2`, the first build on `feature-b` will automatically be tagged `v1.3.5-preview.3`.
* **Promoting Nested Branches to Production (`-PR`):**
  * **Scenario A — Direct promotion of the deeper branch (`fireflow -PR -C feature-b`):**  
    Merges `preview/feature-b` directly into `main`. Because Git resolves the full ancestor tree, **both `feature-a` and `feature-b` commits are cleanly merged into `main` in a single step** and released under the final version (`v1.3.5`).
  * **Scenario B — Staged promotion (`feature-a` first, `feature-b` later):**  
    1. Promoting `feature-a` first (`fireflow -PR -C feature-a`) releases `v1.3.5` containing only `feature-a` changes.  
    2. Continue developing or testing on `feature-b`.  
    3. Later, promoting `feature-b` (`fireflow -PR -C feature-b`) cleanly merges only the remaining `feature-b` delta commits into `main` as `v1.3.6` without merge conflicts.

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

### 6. Subsequent Test Release on an Active Preview Branch (Auto Channel Detection)
```powershell
# When already on 'preview/test', -C is automatically detected:
fireflow "Additional fixes on preview" -P
```

---

## Verified in Production / Tested Workflows

FireFlow is rigorously field-tested on real Firebase projects managing multi-site hosting, Cloud Functions, and Firestore security rules. The following core workflows have been fully verified in production:

| Workflow | Key Command | Verification Status & Details |
| :--- | :--- | :--- |
| **Standard Live Release** | `fireflow "message" [patch\|minor\|major]` | **Verified.** Direct version increment, byte-exact `__VERSION__` HTML injection & restoration, atomic Firebase deploy, Git commit, release tag creation (`vX.Y.Z`), and push to `main`. |
| **Custom Preview Branching & Multi-Step Iteration** | `fireflow "message" -P -C <channel>` | **Verified.** Automatic `preview/<channel>` branch creation, sequential build numbers (`vX.Y.Z-preview.1` continuously verified through `preview.5`+), isolated Firebase Preview Channel deployment, and HTML placeholder preservation. |
| **Smart Channel Auto-Detection** | `fireflow "message" -P` | **Verified.** When executed on an active `preview/*` branch without `-C`, FireFlow automatically detects the active channel and maintains the branch context without redundant flags. |
| **First-Level Promotion (`-PR`)** | `fireflow -PR -C <channel>` | **Verified.** Switches to `main`, pulls latest changes, cleanly merges `preview/<channel>` via `--no-ff`, converts preview tag to final clean release tag (`vX.Y.Z`), and runs live Firebase deploy with HTML sync. |
| **Selective Component Deploy** | `fireflow "rules update" -O firestore:rules` | **Verified.** Deploys targeted backend components while synchronizing the HTML version display, keeping the client UI and Git release state in perfect sync. |

---

## Tool Self-Versioning
FireFlow automatically tracks its own release lifecycle using its own internal version variable `$ToolVersion` synchronized with its repository tags.

---

## License

This project is licensed under the [GNU General Public License v3.0 (GPLv3)](LICENSE). See the `LICENSE` file for details.

---

<a id="fireflow-cli-hu"></a>
# FireFlow CLI (Magyar)

**Verzió:** `v1.2.2`  
**Kiadás dátuma:** 2026. október 24.  
**Típus:** Univerzális Firebase Deploy, Git Branch és Verziókezelő Eszköz (PowerShell)  
**Licenc:** GNU GPLv3

---

## Áttekintés

A **FireFlow** (`fireflow.ps1`) egy egyfájlos, projekttől független CI/CD és kiadáskezelő (release management) parancssori eszköz Firebase alapú webalkalmazásokhoz. 

Célja, hogy egyetlen rövid paranccsal összehangolja a **Firebase Hosting, Cloud Functions, Firestore Rules és Storage** komponensek éles vagy teszt (preview) telepítését a **Git verziókezeléssel** (branch-ek, commitok, tagek), miközben garantálja, hogy a böngészőben megjelenő HTML felületen mindig a ténylegesen futó Git verziószám látszódjon.

### Főbb képességek
* **Rövid, egy-két betűs kapcsolók:** Minimális gépelés a napi munkafolyamatok során (`-P`, `-PR`, `-C`, `-T`, `-O`, `-I`, `-L`, `-h`).
* **Intelligens csatornafelismerés:** Ha egy aktív `preview/<csatorna>` ágon állsz, a `-Channel` / `-C` megadása elhagyható mind a preview deploy (`-P`), mind a véglegesítés (`-PR`) során; a script automatikusan felismeri az ágból.
* **Nem-főági elágazás védelme (Nested Fork Guard):** Figyelmeztet, ha nem a főágról (pl. egy másik tesztágról) indítanál új preview ágat, így megelőzi a véletlen egymásba ágyazott commit-öröklődést.
* **Bájt-pontos HTML verzió-injektálás:** A `__VERSION__` helyőrző cseréjét és védett `finally` visszaállítását bájt-pontosan, BOM-mentes UTF-8 kódolással végzi, megóvva az eredeti fájlstruktúrát és soremeléseket.
* **Kétnyelvű működés és tartós nyelvmentés:** Teljes angol és magyar támogatás (`-L en` / `-L hu` / `-L auto`). A választott nyelvet a script a helyi `.fireflow-lang` fájlban tartósan elmenti a jövőbeli futtatásokhoz. Ha nincs beállítva, automatikusan igazodik a rendszernyelvhez.
* **Globális CLI telepítés (`-Install` / `-I`):** Egyszeri beállítás a PowerShell `$PROFILE`-ban, amely lehetővé teszi a `fireflow` futtatását bármely könyvtárból a script repókba másolgatása nélkül. Kezeli a `-?` kapcsolót is a natív Get-Help felülbírálásával.
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
| **`-C`** | `-Channel` | `preview` | A Firebase Preview csatorna és a teszt Git ág (`preview/<Channel>`) neve (`preview/*` ágon automatikusan felismert). |
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
1. **Ágkezelés és Elágazásvédelem:** A főágon állva automatikusan létrehozza vagy átvált a `preview/<Channel>` ágra. Ha már egy `preview/<csatorna>` ágon vagy és elhagyod a `-C` kapcsolót, automatikusan felismeri az aktív csatornát. Ha nem a főágról (pl. egy másik tesztágról) indítanál új preview ágat, a FireFlow egyértelmű figyelmeztetést ad és megerősítést kér.
2. Kiszámolja a következő verziót, és ellátja egy növekvő teszt-azonosítóval: pl. `v1.0.11-preview.1` (a következő futtatáskor `v1.0.11-preview.2`).
3. A HTML fájlokban bájt-pontosan lecseréli a `__VERSION__` placeholdert erre a preview verzióra.
4. A hostingot a megadott Firebase Preview Channelre (`firebase hosting:channel:deploy`) tölti fel, míg az esetleges egyéb komponenseket (`-O`) frissíti.
5. Védett módon visszaállítja a HTML placeholdert, majd commitol, tagel és pushol a `preview/<Channel>` Git ágra.

### 3. `promote` mód (`-PR` kapcsoló)
Amikor a preview csatornán minden teszt sikeres volt, ez a mód véglegesíti a kiadást:
1. Megköveteli a tiszta munkakönyvtárat (minden változás legyen már commitolva a preview ágon).
2. Ha egy `preview/<csatorna>` ágon állsz, a `-C` elhagyása esetén is automatikusan felismeri az adott csatornát.
3. Átvált a főágra (`main`), frissíti azt (`git pull`), majd beolvasztja (`git merge --no-ff`) a preview ágat.
4. A verziószámot lecsupaszítja végleges formátumra (pl. a `v1.0.11-preview.2`-ből tiszta `v1.0.11` lesz).
5. Elvégzi a teljes éles Firebase deployt a frissített HTML verziószámmal, majd felteszi a végleges Git taget és pusholja a főágat.

### 4. Egymásba ágyazott Preview ágak (Többszintű elágazások)
Összetett fejlesztési feladatok során előfordulhat, hogy egy új preview csatornát nem a főágból (`main`), hanem egy már létező, aktív tesztágból szeretnél indítani (például a `preview/feature-b` ágat a `preview/feature-a` ágból):

* **Elágazásvédelem és Figyelmeztetés:** Ha a `fireflow "Al-funkció indítása" -P -C feature-b` parancsot úgy futtatod, hogy éppen a `preview/feature-a` ágon állsz, a FireFlow észleli a nem-főági elágazást. Kiemelt sárga figyelmeztetést jelenít meg és külön megerősítést kér:
  ```text
  FIGYELEM: Nem a főágon (main), hanem a(z) 'preview/feature-a' ágon állsz!
  Az új 'preview/feature-b' ág ebből fog elágazni (vagy ide vált át), így örökölni fogja annak eddigi commitjait.
  Biztosan elágaztatod a(z) 'preview/feature-b' preview ágat a(z) 'preview/feature-a' ágból a főág (main) helyett? [I/N]
  ```
* **Git előzmények öröklődése és Verziózás:** A `preview/feature-b` ág a `preview/feature-a` legutolsó commitjából ágazik el, így hiánytalanul örökli annak összes commitját. A teszt verziószámláló a közös alapverzió alapján szekvenciálisan növekszik: ha a `feature-a` ágon `v1.3.5-preview.1` és `v1.3.5-preview.2` tagek születtek, a `feature-b` első kiadása automatikusan a `v1.3.5-preview.3` build azonosítót kapja.
* **Egymásba ágyazott ágak élesítése (`-PR`):**
  * **A forgatókönyv — A mélyebb ág közvetlen élesítése (`fireflow -PR -C feature-b`):**  
    Közvetlenül a `main` ágba olvassza be a `preview/feature-b` ágat. Mivel a Git a teljes ősi fastruktúrát figyelembe veszi, **mind a `feature-a`, mind a `feature-b` commitjai egyszerre, egyetlen lépésben kerülnek a `main` ágba**, végleges kiadásként (`v1.3.5`).
  * **B forgatókönyv — Lépcsőzetes élesítés (`feature-a` először, majd később `feature-b`):**  
    1. Először a `feature-a` élesítése: a `fireflow -PR -C feature-a` beolvasztja a `feature-a` ágat a `main`-be `v1.3.5` verzióként.  
    2. A munka és tesztelés folytatódik a `feature-b` ágon.  
    3. Később a `feature-b` élesítése: a `fireflow -PR -C feature-b` beolvasztja a fennmaradó változásokat a `main`-be `v1.3.6` verzióként. Mivel a `feature-a` ekkorra már a `main` része, a Git tisztán, konfliktusok nélkül csak a `feature-b` saját delta commitjait egyesíti.

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

### 6. További teszt kiadás egy már aktív preview ágon (Automatikus csatornafelismerés)
```powershell
# Ha már a 'preview/teszt' ágon állsz, a -C automatikusan felismerésre kerül:
fireflow "További javítások a teszt ágon" -P
```

---

## Élesben Tesztelt Munkafolyamatok

A FireFlow valós, éles Firebase projekteken lett alaposan tesztelve multi-site hosting, Cloud Functions és Firestore szabályok környezetében. Az alábbi kulcsfontosságú munkafolyamatok igazoltan és stabilan működnek éles környezetben:

| Munkafolyamat | Fő Parancs | Tesztelési Állapot és Részletek |
| :--- | :--- | :--- |
| **Standard Éles Kiadás** | `fireflow "üzenet" [patch\|minor\|major]` | **Igazolt.** Közvetlen verzióléptetés, bájt-pontos `__VERSION__` csere a HTML fájlokban, atomi Firebase deploy, helyőrző visszaállítása, Git commit, végleges release tag (`vX.Y.Z`) és push a `main` ágra. |
| **Preview Csatorna & Többlépcsős Iteráció** | `fireflow "üzenet" -P -C <csatorna>` | **Igazolt.** Automatikus `preview/<csatorna>` ág létrehozás, szekvenciális teszt build növelés (`vX.Y.Z-preview.1`-től `preview.5`+-ig folyamatosan igazolva), elkülönített Firebase preview csatornára publikálás, forrásfájl integritás megőrzése. |
| **Intelligens Csatornafelismerés** | `fireflow "üzenet" -P` | **Igazolt.** Aktív `preview/*` ágon állva a `-C` elhagyható; a script automatikusan felismeri a csatornát és kontextusban tartja a fejlesztést. |
| **Első szintű Promote (`-PR`)** | `fireflow -PR -C <csatorna>` | **Igazolt.** Frissíti a `main` ágat, tiszta `--no-ff` merge-dzsel beolvasztja a `preview/<csatorna>` ágat, a preview taget végleges `vX.Y.Z` formátumra cseréli, és éles deployt futtat HTML verziószinkronnal. |
| **Szelektív Komponens Deploy** | `fireflow "szabályok" -O firestore:rules` | **Igazolt.** Célzott háttérkomponensek élesítése a HTML verziószám egyidejű szinkronizálásával, így a felületen a verziószám mindig szinkronban marad a Git release állapottal. |

---

## Eszköz önverziózása
A FireFlow CLI belső verziókövető változóval (`$ToolVersion`) rendelkezik, amely szinkronban van a saját tárolójának Git tagjeivel.

---

## Licenc

Ez a projekt a [GNU General Public License v3.0 (GPLv3)](LICENSE) feltételei szerint van licencelve. Részletekért lásd a `LICENSE` fájlt.

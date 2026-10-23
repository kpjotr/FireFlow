# FireFlow CLI

**Verzió:** `v1.0.0`  
**Kiadás dátuma:** 2026. október 23.  
**Típus:** Univerzális Firebase Deploy, Git Branch és Verziókezelő Eszköz (PowerShell)  
**Licenc:** GNU GPLv3

---

## Áttekintés

A **FireFlow** (`fireflow.ps1`) egy egyfájlos, projekttől független CI/CD és kiadáskezelő (release management) parancssori eszköz Firebase alapú webalkalmazásokhoz. 

Célja, hogy egyetlen rövid paranccsal összehangolja a **Firebase Hosting, Cloud Functions, Firestore Rules és Storage** komponensek éles vagy teszt (preview) telepítését a **Git verziókezeléssel** (branch-ek, commitok, tagek), miközben garantálja, hogy a böngészőben megjelenő HTML felületen mindig a ténylegesen futó Git verziószám látszódjon.

### Főbb képességek
* **Rövid, egy-két betűs kapcsolók:** Minimális gépelés a napi munkafolyamatok során (`-P`, `-PR`, `-C`, `-T`, `-O`, `-h`).
* **In-Place Verzió-injektálás és Visszaállítás:** Ideiglenes mappák másolgatása helyett közvetlenül a forrás HTML fájlokban cseréli le a `__VERSION__` helyőrzőt a deploy idejére, majd egy védett `finally` blokkban azonnal visszaállítja az eredeti állapotot a Git commit előtt.
* **Globális Verziószinkron:** Akkor is frissíti a HTML-ben látható verziószámot (és a hostingot), ha az adott körben csak háttérszolgáltatást (pl. `firestore:rules` vagy `functions`) módosítottál.
* **Multi-Site (Target) támogatás:** Automatikusan elemzi a `firebase.json` fájlt, és kezeli az egyedi hosting targeteket.
* **Integrált Preview és Branch munkafolyamat:** Teszteléskor (`-P`) automatikusan külön Git ágra vált (`preview/<csatorna>`), növeli a teszt build számát (`vX.Y.Z-preview.N`), és a Firebase Preview Channelre publikál.
* **Egygombos Promote és Merge:** A tesztelés végeztével (`-PR`) beolvasztja a preview ágat a főágba (`main`), lecsupaszítja a verziószámot véglegesre (`vX.Y.Z`), és élesíti a rendszert.
* **Beépített terminálos súgó:** A `.\fireflow.ps1 -h` parancs bármikor megjeleníti a színes puskázót.

---

## Előfeltételek és Beállítás

1. **Környezet:** Windows PowerShell 5.1+ vagy PowerShell Core (pwsh), telepített és bejelentkezett `git` és `firebase-tools` (Firebase CLI).
2. **Elhelyezés:** Másold a `fireflow.ps1` fájlt a Firebase projekted gyökérkönyvtárába (ahol a `firebase.json` és a `.git` mappa található).
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
| **`-V`** | `-Version` | `false` | Kiírja a FireFlow CLI eszköz saját verziószámát, majd kilép. |
| **`-H`**, **`-?`** | `-Help` | `false` | Megjeleníti a részletes parancssori súgót és puskázót, majd kilép. |

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

### Súgó és verzió lekérdezése
```powershell
.\fireflow.ps1 -h
.\fireflow.ps1 -v
```

### 1. Gyors éles (patch) kiadás
```powershell
.\fireflow.ps1 "Hibajavítás a főoldalon"
```

### 2. Éles (minor) kiadás egy adott hosting targetre
```powershell
.\fireflow.ps1 "Új modul" minor -T app
```

### 3. Csak Firestore szabályok frissítése (HTML verziószinkronnal)
```powershell
.\fireflow.ps1 "Szabályok szigorítása" -O firestore:rules
```

### 4. Fejlesztés küldése Preview csatornára
```powershell
.\fireflow.ps1 "Új naptár teszt" -P -C teszt -T app
```

### 5. Letesztelt Preview ág beolvasztása (promote) és élesítése
```powershell
.\fireflow.ps1 -PR -C teszt -T app
```

---

## Licenc

Ez a projekt a [GNU General Public License v3.0 (GPLv3)](LICENSE) feltételei szerint van licencelve. Részletekért lásd a `LICENSE` fájlt.

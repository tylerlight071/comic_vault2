# 📚 Comic Vault

A premium, Apple TV–inspired personal comic book library for Android.
Scan barcodes, pull full metadata from Comic Vine, and manage your collection — all stored locally on device.

---

## ✨ Features

| Feature | Detail |
|---|---|
| Barcode scanner | Camera scan with animated overlay |
| Comic Vine metadata | Cover, issue #, series, year, publisher, writer & artist credits, synopsis |
| Local storage | SQLite — no account, no cloud, no ads |
| Read / Unread tracking | One tap toggle |
| Star ratings | 1–5 stars per issue |
| Filters | All / Read / Unread, Publisher, Min star rating |
| Sort | Date added, Title, Series, Publisher, Rating |
| Premium dark UI | Pure black, large cover art, Inter typeface |

---

## 🚀 Setup

### 1. Flutter

Requires Flutter **3.x** with Dart **3.0+**.

```bash
flutter pub get
flutter run
```

### 2. Comic Vine API Key (free)

1. Go to **[comicvine.gamespot.com/api](https://comicvine.gamespot.com/api)**
2. Create a free account
3. Copy your API key
4. On first launch the app will ask you to paste it in

> Your key is stored locally in SharedPreferences — never sent anywhere except Comic Vine's own servers.

### 3. Android permissions

The `AndroidManifest.xml` already includes:
- `CAMERA` — for the barcode scanner
- `INTERNET` — for Comic Vine API + cover art

If you create a fresh Flutter project, copy the `android/app/src/main/AndroidManifest.xml`
provided here over your existing one (or manually add the two `uses-permission` lines).

---

## 📁 Project Structure

```
lib/
├── main.dart                         # App entry, theme
├── models/
│   └── comic.dart                    # Data model
├── services/
│   ├── database_service.dart         # SQLite CRUD
│   └── comic_vine_service.dart       # Comic Vine REST API
├── screens/
│   ├── onboarding_screen.dart        # API key setup (first launch)
│   ├── home_screen.dart              # Library grid + filters
│   ├── scanner_screen.dart           # Barcode camera
│   ├── search_results_screen.dart    # Pick comic from CV results
│   └── comic_detail_screen.dart      # Full detail + edit
└── widgets/
    ├── comic_card.dart               # Grid card with Hero
    └── star_rating_widget.dart       # Tappable stars
```

---

## 📦 Dependencies

| Package | Purpose |
|---|---|
| `mobile_scanner` | Barcode / QR scanning |
| `sqflite` + `path` | Local SQLite database |
| `http` | Comic Vine API calls |
| `cached_network_image` | Cover art with caching |
| `google_fonts` (Inter) | Premium typography |
| `flutter_animate` | Micro-animations & shimmer |
| `shared_preferences` | API key storage |

All free and open source.

---

## 💡 Barcode tips

Comic barcodes are UPC-A codes on the back cover. Comic Vine's search doesn't
directly index UPCs, so the scanned value is used as a pre-filled search query.

- If the barcode scan returns no results → **edit the query** to the series title
- Searching by series name + issue number (e.g. `Amazing Spider-Man 1`) works best

---

## 🛠 Changing your API key

Settings → long-press the title bar (coming in a future update), or clear app
data to reset. Alternatively, find the key in:

```
SharedPreferences → 'comic_vine_api_key'
```

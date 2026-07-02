# Design Spec: Mecha Chameleon Prop Hunt (Multiplayer Edition)

Game 3D multiplayer online (P2P/ENet) di mana pemain terhubung via lobby menggunakan IP address. Salah satu pemain akan dipilih acak menjadi **Hunter** yang mencari pemain lain yang menjadi **Prop** (Mecha Chameleon). Pemain Prop memiliki kemampuan untuk meniru bentuk objek di sekitar dan mengubah warna/tekstur untuk berkamuflase dengan permukaan lingkungan. Hunter menggunakan sensor jarak (radar beep) dan senjata laser dengan sistem cooldown untuk menemukan dan mengeliminasi Prop.

---

## 1. Arsitektur & Struktur Proyek

Game ini dibangun menggunakan **Godot Engine 4.7** dan **Jolt Physics** dengan pendekatan **Modular Component-Based** dan arsitektur jaringan **High-level Multiplayer (Server-Client)**.

### Struktur File

```text
res://
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-07-02-mecha-chameleon-design.md # Dokumen desain ini
├── assets/
│   └── shaders/
│       └── camouflage.gdshader  # Shader albedo blending untuk chameleon
├── common/
│   ├── game_manager.gd         # Autoload singleton (skor, status jaringan, info lobby)
│   └── multiplayer_manager.gd   # Autoload singleton untuk fungsi networking ENet
├── components/
│   ├── camera_controller.gd    # Komponen pengatur kamera FPP/TPP (Mouse Look)
│   ├── color_blender.gd        # Komponen kamuflase warna
│   ├── prop_transformer.gd     # Komponen peniru objek 3D & collision
│   ├── scanner_radar.gd        # Komponen radar kedekatan untuk Hunter
│   └── laser_weapon.gd         # Komponen senjata laser untuk Hunter
├── scenes/
│   ├── lobby.tscn              # UI Lobby (Host, Join, IP Input, Start Game)
│   ├── main.tscn               # Arena utama permainan (World3D & Spawn Points)
│   ├── map.tscn                # Subscene peta permainan (dekorasi & terrain)
│   ├── player.tscn             # Player Character (CharacterBody3D + MultiplayerSynchronizer)
│   └── ui.tscn                 # HUD info (HP, radar, ammo/overheat)
```

---

## 2. Jaringan & Koneksi (ENet Multiplayers)

### A. Autoload `multiplayer_manager.gd`
* Bertanggung jawab menginisialisasi `ENetMultiplayerPeer`.
* Menyediakan fungsi `host_game(port)` dan `join_game(ip, port)`.
* Mengatur sinyal jaringan Godot:
  * `peer_connected`: Menambahkan pemain baru ke daftar lobby.
  * `peer_disconnected`: Menghapus pemain dari daftar lobby dan game.
* Mengelola daftar pemain (`players = {}`) yang berisi ID peer dan nama pemain.

### B. Transisi Scene & Spawning
* `MultiplayerSpawner` diletakkan di `main.tscn` untuk menyebarkan instansi player di server ke semua client secara otomatis.
* Menggunakan `MultiplayerSynchronizer` pada `player.tscn` untuk mereplikasi properti `position`, `rotation`, dan input/velocity jika diperlukan di seluruh jaringan.
* Server memanggil `change_scene` ke `main.tscn` ketika tombol **Start Game** ditekan di lobby.

### C. Alokasi Peran (Role Assignment)
* Saat transisi ke scene utama `main.tscn` selesai di server, server secara acak memilih 1 peer ID sebagai `Role.HUNTER`, dan peer ID lainnya menjadi `Role.PROP`.
* Server menyebarkan penugasan peran ini menggunakan RPC (`@rpc("any_peer", "call_local", "reliable")`) ke semua client.
* Masing-masing instance player lokal akan mengaktifkan/menonaktifkan komponen berdasarkan peran yang diterimanya.

---

## 3. Detail Komponen & Mekanik Baru

### A. Base Player (`player.tscn` & `player.gd`)
* Menggunakan `CharacterBody3D` dengan gerakan dasar 3D menggunakan kontrol standar **WASD**.
* Menggunakan Mouse Look untuk rotasi kamera dan badan pemain (menggunakan `Input.MOUSE_MODE_CAPTURED`).
* Memiliki node `MultiplayerSynchronizer` untuk mereplikasi posisi dan rotasi secara otomatis.
* Properti `is_multiplayer_authority()` digunakan untuk memastikan input lokal hanya menggerakkan karakter milik pemain itu sendiri.

### B. Komponen Kamera (`camera_controller.gd`)
* Menangkap input mouse untuk memutar kamera secara vertikal (pitch) dan badan player secara horizontal (yaw).
* Tombol `V` digunakan untuk beralih antara First-Person (FPP) dan Third-Person (TPP) menggunakan `SpringArm3D`.

---

## 4. UI Lobby (`lobby.tscn`)

* Input field untuk mengisi **Player Name** dan **Host IP Address**.
* Tombol **Host Game** (memulai server pada port default `8910`).
* Tombol **Join Game** (menghubungkan ke IP address yang ditentukan).
* List View untuk menampilkan daftar pemain yang terhubung di lobby.
* Tombol **Start Game** (hanya terlihat/aktif untuk Host).

---

## 5. UI Radial Menu & Mekanik Scanning (Prop Transformation)

### A. Mekanik Scanning (`prop_transformer.gd` / `scenes/player.gd`)
* Pemain dengan peran `PROP` dibekali RayCast3D untuk mendeteksi objek di grup `"InteractableProps"`.
* Ketika mendeteksi objek, HUD memunculkan prompt interaksi (misal: "Tahan [F] untuk men-scan").
* Proses scanning membutuhkan waktu 1.5 detik (terdapat visual *progress bar* melingkar di HUD).
* Jika selesai, objek tersebut akan ditambahkan ke daftar katalog wujud lokal pemain: `scanned_props[prop_name] = { "mesh_path": String, "shape_path": String }`.

### B. UI Radial Menu (`scenes/ui.tscn` / `scenes/player.gd`)
* Di dalam HUD (`ui.tscn`), ditambahkan antarmuka **Radial Menu** yang tersembunyi secara default.
* Saat tombol **`Tab`** ditekan dan ditahan oleh pemain:
  * Kursor mouse dibebaskan (`Input.MOUSE_MODE_VISIBLE`).
  * Kontrol rotasi kamera dihentikan sementara.
  * Tampilan menu lingkaran muncul di tengah layar, terbagi menjadi sektor-sektor sesuai jumlah objek yang telah berhasil di-scan.
  * Setiap sektor memuat Nama/Ikon objek.
  * Ketika mouse mendekati sektor tertentu, sektor tersebut disorot (*hover state*).
  * Saat tombol **`Tab`** dilepas, pemain berubah wujud menjadi objek pada sektor yang disorot, lalu kursor ditangkap kembali (`Input.MOUSE_MODE_CAPTURED`).

### C. Sinkronisasi Perubahan Wujud Jaringan
* Ketika pemain memilih objek dari Radial Menu:
  * Pemain mengirim RPC request ke Server: `rpc_id(1, "request_transformation", prop_name)`.
  * Server memvalidasi dan mengubah mesh & collision player di server.
  * Server memperbarui variable tersinkronisasi `current_prop_name` yang di-export dan diamati oleh MultiplayerSynchronizer di semua client.
  * Semua client yang mendeteksi perubahan variable `current_prop_name` akan memperbarui visual instance player tersebut di layarnya secara lokal.


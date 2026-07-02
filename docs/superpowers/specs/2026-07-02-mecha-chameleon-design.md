# Design Spec: Mecha Chameleon Prop Hunt

Game 3D multiplayer lokal (split-screen) di mana satu pemain bermain sebagai **Hunter** yang mencari pemain lain yang bermain sebagai **Prop** (Mecha Chameleon). Pemain Prop memiliki kemampuan untuk meniru bentuk objek di sekitar dan mengubah warna/tekstur untuk berkamuflase dengan permukaan lingkungan. Hunter menggunakan sensor jarak (radar beep) dan senjata laser dengan sistem cooldown untuk menemukan dan mengeliminasi Prop.

---

## 1. Arsitektur & Struktur Proyek

Game ini dibangun menggunakan **Godot Engine 4.7** dan **Jolt Physics** dengan pendekatan **Modular Component-Based**.

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
│   └── game_manager.gd         # Autoload singleton untuk aturan game (skor, waktu, restart)
├── components/
│   ├── camera_controller.gd    # Komponen pengatur kamera FPP/TPP
│   ├── color_blender.gd        # Komponen kamuflase warna (mendeteksi & memblend material)
│   ├── prop_transformer.gd     # Komponen peniru objek 3D & collision
│   ├── scanner_radar.gd        # Komponen radar kedekatan (proximity sensor) untuk Hunter
│   └── laser_weapon.gd         # Komponen senjata laser untuk Hunter
├── scenes/
│   ├── main.tscn               # Main scene (mengatur SubViewport split-screen)
│   ├── map.tscn                # Scene arena bermain beserta objek-objek dekorasi
│   ├── player.tscn             # Base Player (CharacterBody3D)
│   └── ui.tscn                 # CanvasLayer untuk HUD info (HP, radar, ammo/overheat)
```

---

## 2. Detail Komponen & Mekanik

### A. Base Player (`player.tscn`)
* Menggunakan `CharacterBody3D` dengan gerakan dasar 3D (walk, jump, slide).
* Memiliki variabel `player_id` (1 atau 2) untuk membedakan input mapping (misal: `p1_move_forward` vs `p2_move_forward`).
* Memiliki status `role` (`Role.HUNTER` atau `Role.PROP`) yang ditentukan saat inisialisasi di `main.tscn`. Komponen yang tidak relevan dengan role akan dinonaktifkan (`set_process(false)`, `set_physics_process(false)`, dll).

### B. Komponen Kamera (`camera_controller.gd`)
* Mengatur penempatan kamera relatif terhadap `CharacterBody3D`.
* Mendukung pergantian perspektif FPP ke TPP saat tombol interaksi ditekan (misal: menekan tombol `V` atau *gamepad toggle*).
* FPP: Kamera berada di tinggi mata karakter, kepala model disembunyikan.
* TPP: Kamera diletakkan di belakang karakter menggunakan `SpringArm3D` untuk menghindari kamera menembus tembok.

### C. Komponen Transformasi (`prop_transformer.gd`)
* Menyimpan reference visual asli pemain.
* Memiliki `RayCast3D` di depan kamera player.
* Jika menunjuk objek dalam group `"InteractableProps"` dan tombol interaksi ditekan:
  1. Ambil mesh dari target.
  2. Sembunyikan mesh visual asli player.
  3. Instantiate duplikasi mesh target di bawah node player, sesuaikan tinggi/pivot.
  4. Ambil `CollisionShape3D` dari target, nonaktifkan collision asli player, dan terapkan collision baru sesuai bentuk objek agar ukuran fisik berubah secara real-time.

### D. Komponen Kamuflase Warna (`color_blender.gd`)
* Memiliki `RayCast3D` yang selalu menghadap ke bawah untuk mendeteksi permukaan lantai/tanah.
* Membaca albedo warna atau metadata warna dari collider lantai.
* Menerapkan warna tersebut ke shader material objek/player saat diam.
* Transisi warna menggunakan `Tween` agar halus dari warna asli objek ke warna permukaan (misal, jika berdiri di atas karpet merah, objek perlahan berubah kemerahan).

### E. Komponen Radar Sensor (`scanner_radar.gd`)
* Hanya aktif untuk Hunter.
* Menghitung jarak (`global_position.distance_to`) ke semua player dengan role `PROP`.
* Memperbarui UI Hunter dengan indikator kekuatan sinyal (dekat/jauh).
* Memutar audio beeping di mana interval waktu beep mengecil seiring mengecilnya jarak (misal: `beep_cooldown = clamp(distance / 10.0, 0.1, 2.0)`).

### F. Komponen Senjata Laser (`laser_weapon.gd`)
* Hanya aktif untuk Hunter.
* Menembakkan Raycast dari tengah kamera.
* Menampilkan efek visual garis laser instan menggunakan `MeshInstance3D` silinder tipis / `ImmediateMesh`.
* Mengonsumsi panas (*heat*). Jika mencapai 100% (overheat), senjata terkunci selama 3 detik sebelum dingin kembali.
* Jika mengenai Prop, memicu pengurangan HP pada Prop dan memenangkan game jika HP mencapai 0.

---

## 3. Split-screen & UI

* Di dalam `main.tscn`, terdapat `HBoxContainer` atau `VBoxContainer` yang membagi layar menjadi 2 `SubViewportContainer`.
* Masing-masing `SubViewport` memiliki dunianya sendiri tetapi berbagi `World3D` yang sama.
* `Player 1` dimasukkan ke `Viewport 1`, `Player 2` dimasukkan ke `Viewport 2`.
* HUD masing-masing player di-render di atas viewport masing-masing untuk menampilkan indikator radar (Hunter) dan indikator cooldown warna/kamuflase (Prop).

---

## 4. Rencana Pengujian & Verifikasi

### Pengujian Manual
1. **Pergerakan & Kamera**: Memastikan Player 1 dan Player 2 dapat bergerak secara independen menggunakan skema input yang berbeda (Keyboard & Controller). Verifikasi tombol ganti FPP/TPP berfungsi dengan benar.
2. **Transformasi**: Player Prop mendekati objek kotak, menekan tombol interaksi, dan berubah menjadi kotak dengan perubahan hitbox yang sesuai.
3. **Kamuflase Warna**: Player Prop berdiri di atas area berwarna merah, lalu area berwarna biru. Warna visual objek berubah secara perlahan menyesuaikan lantai.
4. **Radar**: Player Hunter berjalan mendekati Prop. Beep suara radar berdetak semakin cepat seiring dekatnya jarak.
5. **Senjata & Aturan Main**: Hunter menembak Prop, HP Prop berkurang, game memicu kondisi menang/kalah ketika waktu habis atau HP Prop habis.

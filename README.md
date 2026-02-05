
# TA-Monitor - Thesis Monitoring Platform 🎓 - GROUP PROJECT

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Material 3](https://img.shields.io/badge/Material--3-6750A4?style=for-the-badge&logo=materialdesign&logoColor=white)](https://m3.material.io)

**TA-Monitor** adalah platform profesional berbasis web yang dirancang untuk menyederhanakan dan memodernisasi proses bimbingan Tugas Akhir (TA). Platform ini menghubungkan mahasiswa dan dosen dengan fokus pada akuntabilitas, pelacakan riwayat, dan komunikasi real-time.

---

## Tampilan Aplikasi

![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot1.png)
![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot2.png)
![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot3.png)
![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot4.png)
![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot5.png)
![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot6.png)
![image](https://github.com/ZwetaTriRahma/Project-TA-Monitor/blob/865a181fd26745b081d152096d9323683438ffd6/screenshot7.png)

  
## ✨ Fitur Utama

### 👨‍🎓 Untuk Mahasiswa
- **Dashboard Interaktif**: Pantau progres TA Anda dengan indikator visual *progress ring*.
- **Submission Versioning**: Riwayat pengajuan tetap terjaga. Revisi disimpan sebagai data baru, menciptakan jejak audit yang jelas.
- **Pelacakan Progres**: Pembaruan status secara real-time (Pending, Revisi, Disetujui).
- **Thread Diskusi**: Diskusikan umpan balik langsung pada file pengajuan bimbingan dengan dosen Anda.

### 👨‍🏫 Untuk Dosen
- **Ringkasan Fakultas**: Gambaran umum tingkat tinggi dari semua mahasiswa bimbingan dan progres mereka saat ini.
- **Review File Mendetail**: Memberikan feedback terstruktur dengan opsi untuk melampirkan gambar/tangkapan layar pendukung.
- **Komunikasi Real-time**: Chat instan dan diskusi berbasis thread untuk bimbingan yang lebih efektif.
- **Manajemen Tugas**: Memantau ulasan yang tertunda di seluruh daftar mahasiswa.

### 🛡️ Infrastruktur Inti
- **Sistem Desain Indigo**: UI modern premium yang dibangun dengan Material 3 dan estetika glassmorphism.
- **Autentikasi Aman**: Terintegrasi dengan Firebase Auth dan dukungan Google Sign-In.
- **Penyimpanan Cloud**: Penanganan dokumen dan gambar yang mulus melalui Cloudinary dan Firestore.
- **Lintas Platform**: Dioptimalkan untuk pengalaman web yang lancar.

---

## 🛠 Tech Stack

- **Frontend**: [Flutter](https://flutter.dev) (Web Management)
- **Backend**: [Google Firebase](https://firebase.google.com) (Auth, Firestore)
- **Media**: [Cloudinary](https://cloudinary.com) (File & Image Hosting)
- **Theme**: Material Design 3 (Indigo Seed Palette)

---

## 🚀 Memulai

### Prasyarat
- Flutter SDK (Versi Stabil Terbaru)
- Akun Firebase
- Akun Cloudinary (untuk upload file)

### Instalasi

1. **Clone Repositori**
   ```bash
   git clone https://github.com/ZwetaTriRahma/Project-TA-Monitor.git
   cd projectuasmonitormahasiswa
   ```

2. **Instal Dependensi**
   ```bash
   flutter pub get
   ```

3. **Konfigurasi Firebase**
   - Letakkan file `firebase_options.dart` atau atur menggunakan [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup).

4. **Jalankan Aplikasi**
   ```bash
   flutter run -d chrome
   ```

---

## 📸 Pandangan Aplikasi

> [!TIP]
> **Prognosis**: Aplikasi menggunakan tema Indigo yang responsif (terang/gelap) yang menyesuaikan dengan lingkungan profesional Anda.

---

## 📄 Lisensi

Proyek ini adalah bagian dari pemenuhan Tugas Akhir Semester (UAS). Didistribusikan di bawah Lisensi MIT. Lihat `LICENSE` untuk informasi lebih lanjut.

---

Dikembangkan dengan ❤️ oleh **Kelompok 1 - Universitas Bina Bangsa*

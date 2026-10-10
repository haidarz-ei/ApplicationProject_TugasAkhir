# Dictionary Data Processing

Proyek ini berisi sekumpulan script Python untuk memproses, membersihkan, dan mem-filter data kamus mentah Inggris-Indonesia sebelum diimpor ke database (Supabase).

## Prasyarat
- Python 3.x terinstal.
- Install library pandas yang dibutuhkan dengan menjalankan perintah:
  ```bash
  pip install -r requirements.txt
  ```

## Alur Kerja (Step-by-step)

**1. Siapkan Data Mentah**
Letakkan file mentah Anda (misalnya `english.jsonl`, `irregular-verbs.json`, dsb) di dalam folder `raw-data/`.

**2. Jalankan Script Secara Berurutan**
Buka terminal/CMD di dalam folder project ini, lalu jalankan script berikut satu per satu:

* **Tahap 1: Filter Bahasa Indonesia**
  ```bash
  python scripts/01_filter_indonesian.py
  ```
  Script ini akan mem-filter data mentah menjadi data awal yang hanya memuat entri bahasa Indonesia.

* **Tahap 2: Gabung Irregular Verbs**
  ```bash
  python scripts/02_merge_irregular_verbs.py
  ```
  Script ini akan menggabungkan hasil tahap 1 dengan daftar *irregular verbs*.

* **Tahap 3: Cleansing & Validasi CSV**
  ```bash
  python scripts/03_clean_validate.py
  ```
  Script terakhir ini merapikan data, memvalidasi format, dan mengekspornya menjadi format CSV.

**3. Ambil Hasil Akhir**
File CSV akhir yang sudah bersih dan siap untuk diimpor ke Supabase akan otomatis dibuat di dalam folder `output/`.

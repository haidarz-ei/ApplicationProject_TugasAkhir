import csv
import os


def process_clean_validate():
    input_csv = os.path.join("output", "merged_with_verbs.csv")
    output_csv = os.path.join("output", "dictionary_final.csv")

    if not os.path.exists(input_csv):
        print(f"Error: File {input_csv} tidak ditemukan.")
        return

    print("Membaca file input...")

    # Baca semua baris
    rows = []
    with open(input_csv, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    total_before = len(rows)
    print(f"Total baris sebelum cleaning: {total_before}\n")

    # --- Step 1: Trim whitespace di semua kolom & normalize pos ke lowercase ---
    for row in rows:
        for key in row:
            if row[key] is not None:
                row[key] = row[key].strip()
            else:
                row[key] = ""
        # Normalize pos ke lowercase
        row["pos"] = row["pos"].lower()

    # --- Step 2: Hapus baris dengan word kosong ---
    before_empty_word = len(rows)
    rows = [r for r in rows if r.get("word", "")]
    removed_empty_word = before_empty_word - len(rows)

    # --- Step 3: Hapus baris dengan definition_en atau definition_id kosong ---
    before_empty_def = len(rows)
    rows = [r for r in rows if r.get("definition_en", "") and r.get("definition_id", "")]
    removed_empty_def = before_empty_def - len(rows)

    # --- Step 4: Hapus duplikat berdasarkan (word, pos) - simpan yang pertama ---
    before_dedup = len(rows)
    seen = set()
    deduped_rows = []
    for row in rows:
        key = (row["word"].lower(), row["pos"])
        if key not in seen:
            seen.add(key)
            deduped_rows.append(row)
    rows = deduped_rows
    removed_duplicates = before_dedup - len(rows)

    # --- Hasil akhir ---
    total_after = len(rows)

    # Tulis output
    fieldnames = ["word", "pos", "definition_en", "definition_id", "v1", "v2", "v3"]
    with open(output_csv, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})

    # Kumpulkan nilai unik pos
    unique_pos = sorted(set(r["pos"] for r in rows))

    # Print laporan
    print("--- Selesai ---")
    print(f"Jumlah baris SEBELUM cleaning: {total_before}")
    print(f"Jumlah baris SETELAH cleaning:  {total_after}")
    print(f"\nRincian penghapusan:")
    print(f"  - Dihapus karena word kosong:      {removed_empty_word}")
    print(f"  - Dihapus karena definisi kosong:   {removed_empty_def}")
    print(f"  - Dihapus karena duplikat (word+pos): {removed_duplicates}")
    total_removed = removed_empty_word + removed_empty_def + removed_duplicates
    print(f"  - TOTAL dihapus:                    {total_removed}")
    print(f"\nNilai unik kolom 'pos' di data final ({len(unique_pos)} jenis):")
    for p in unique_pos:
        count = sum(1 for r in rows if r["pos"] == p)
        print(f"  - {p}: {count} entries")
    print(f"\nHasil disimpan ke: {output_csv}")


if __name__ == "__main__":
    process_clean_validate()

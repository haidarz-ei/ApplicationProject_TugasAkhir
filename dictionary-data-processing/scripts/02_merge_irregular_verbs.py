import json
import csv
import os


def make_regular_past(word):
    """Generate regular past tense form.
    If word ends with 'e', just add 'd'. Otherwise add 'ed'.
    """
    if word.endswith("e"):
        return word + "d"
    return word + "ed"


def process_merge():
    input_csv = os.path.join("output", "filtered_english_indonesian.csv")
    verbs_json = os.path.join("raw-data", "irregular-verbs-json", "Verbs.json")
    output_csv = os.path.join("output", "merged_with_verbs.csv")

    # Validasi file input
    if not os.path.exists(input_csv):
        print(f"Error: File {input_csv} tidak ditemukan.")
        return
    if not os.path.exists(verbs_json):
        print(f"Error: File {verbs_json} tidak ditemukan.")
        return

    # Baca irregular verbs dan buat lookup dictionary (case-insensitive)
    with open(verbs_json, "r", encoding="utf-8") as f:
        verbs_data = json.load(f)

    irregular_lookup = {}
    for verb in verbs_data.get("verbs", []):
        base = verb.get("Base", "").strip().lower()
        if base:
            irregular_lookup[base] = {
                "v1": verb.get("Base", "").strip(),
                "v2": verb.get("Past-simple", "").strip(),
                "v3": verb.get("Past-Participle", "").strip(),
            }

    print(f"Loaded {len(irregular_lookup)} irregular verbs dari Verbs.json")
    print("Memulai pemrosesan CSV...\n")

    # Baca CSV input dan tulis CSV output dengan kolom tambahan
    total_verbs = 0
    irregular_count = 0
    regular_count = 0
    total_rows = 0

    with open(input_csv, "r", encoding="utf-8") as infile, \
         open(output_csv, "w", encoding="utf-8", newline="") as outfile:

        reader = csv.DictReader(infile)
        fieldnames = ["word", "pos", "definition_en", "definition_id", "v1", "v2", "v3"]
        writer = csv.DictWriter(outfile, fieldnames=fieldnames)
        writer.writeheader()

        for row in reader:
            total_rows += 1
            word = row.get("word", "").strip()
            pos = row.get("pos", "").strip()

            v1 = ""
            v2 = ""
            v3 = ""

            if pos == "verb":
                total_verbs += 1
                word_lower = word.lower()

                if word_lower in irregular_lookup:
                    # Irregular verb — ambil dari Verbs.json
                    irregular_count += 1
                    v1 = irregular_lookup[word_lower]["v1"]
                    v2 = irregular_lookup[word_lower]["v2"]
                    v3 = irregular_lookup[word_lower]["v3"]
                else:
                    # Regular verb — auto-generate
                    regular_count += 1
                    v1 = word
                    v2 = make_regular_past(word)
                    v3 = make_regular_past(word)

            writer.writerow({
                "word": word,
                "pos": pos,
                "definition_en": row.get("definition_en", ""),
                "definition_id": row.get("definition_id", ""),
                "v1": v1,
                "v2": v2,
                "v3": v3,
            })

    print("--- Selesai ---")
    print(f"Total baris diproses: {total_rows}")
    print(f"Total baris dengan pos == 'verb': {total_verbs}")
    print(f"  - Irregular verb (match Verbs.json): {irregular_count}")
    print(f"  - Regular verb (auto-generated v2/v3): {regular_count}")
    print(f"\nHasil disimpan ke: {output_csv}")


if __name__ == "__main__":
    process_merge()

import json
import csv
import os

def process_file():
    input_file = os.path.join("raw-data", "kaikki.org-dictionary-English.jsonl")
    output_file = os.path.join("output", "filtered_english_indonesian.csv")

    if not os.path.exists(input_file):
        print(f"Error: File {input_file} tidak ditemukan.")
        return

    total_lines = 0
    filtered_entries = 0
    error_lines = 0

    print("Memulai pemrosesan file...")

    # Memastikan folder output ada
    os.makedirs("output", exist_ok=True)

    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8', newline='') as outfile:
        
        csv_writer = csv.writer(outfile)
        csv_writer.writerow(['word', 'pos', 'definition_en', 'definition_id'])

        for line in infile:
            total_lines += 1
            if total_lines % 100000 == 0:
                print(f"Processed {total_lines} lines...")

            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                error_lines += 1
                continue

            word = data.get("word")
            pos = data.get("pos")
            senses = data.get("senses", [])

            if not word or not pos or not senses:
                continue

            for sense in senses:
                translations = sense.get("translations", [])
                
                # Cek terjemahan bahasa Indonesia
                id_translation = None
                for t in translations:
                    if t.get("code") == "id":
                        id_translation = t.get("word")
                        break
                
                if id_translation:
                    glosses = sense.get("glosses", [])
                    definition_en = glosses[0] if glosses else ""
                    
                    csv_writer.writerow([word, pos, definition_en, id_translation])
                    filtered_entries += 1
                    # Mengambil satu sense yang match (pertama)
                    break 

    percentage = (filtered_entries / total_lines) * 100 if total_lines > 0 else 0

    print("\n--- Selesai ---")
    print(f"Total baris yang diproses: {total_lines}")
    print(f"Total entry yang lolos filter: {filtered_entries}")
    print(f"Persentase yang lolos: {percentage:.2f}%")
    if error_lines > 0:
        print(f"Total baris di-skip karena error: {error_lines}")

if __name__ == "__main__":
    process_file()

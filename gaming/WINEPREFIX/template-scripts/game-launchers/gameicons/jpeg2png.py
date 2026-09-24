import os
import sys
import math
import argparse
from PIL import Image

def color_distance(c1, c2):
    """Bereken het verschil tussen twee RGB(A) kleuren."""
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(c1[:3], c2[:3])))

def remove_background_and_replace(file_path, tolerance=40):
    """Zet een afbeelding om naar PNG met transparante achtergrond en verwijdert het origineel."""
    base_name, ext = os.path.splitext(file_path)
    output_path = f"{base_name}.png"

    try:
        with Image.open(file_path) as img:
            img = img.convert("RGBA")
            pixels = img.load()
            width, height = img.size

            # Pak de kleur van de hoekpixel linksboven (0,0) als achtergrondkleur
            bg_color = pixels[0, 0]

            for y in range(height):
                for x in range(width):
                    current_color = pixels[x, y]
                    dist = color_distance(current_color, bg_color)

                    if dist <= tolerance:
                        # Binnen tolerantie: volledig transparant
                        pixels[x, y] = (0, 0, 0, 0)
                    elif dist < tolerance + 20:
                        # Vloeiende randen (anti-aliasing)
                        alpha = int(255 * ((dist - tolerance) / 20))
                        pixels[x, y] = (current_color[0], current_color[1], current_color[2], alpha)

            img.save(output_path, "PNG")
            print(f"✓ Omgezet naar PNG: {os.path.basename(file_path)} -> {os.path.basename(output_path)}")

        # Verwijder het originele bestand als het geen .png was
        if file_path.lower() != output_path.lower():
            os.remove(file_path)
            print(f"  Origineel verwijderd: {os.path.basename(file_path)}")

    except Exception as e:
        print(f"✗ Fout bij verwerken van {file_path}: {e}")

def process_directory(directory_path, tolerance=40):
    if not os.path.exists(directory_path):
        print(f"Fout: Map '{directory_path}' bestaat niet.")
        sys.exit(1)

    print(f"Map controleren: {directory_path}\n")

    for root, _, files in os.walk(directory_path):
        for file_name in files:
            file_path = os.path.join(root, file_name)
            ext = os.path.splitext(file_name)[1].lower()

            # Sla .png bestanden over
            if ext == '.png':
                print(f"- Overgeslagen (al PNG): {file_name}")
                continue

            # Ondersteunde afbeeldingsextensies verwerken
            if ext in ('.jpg', '.jpeg', '.webp', '.bmp', '.tiff'):
                remove_background_and_replace(file_path, tolerance)

    print("\nVerwerking voltooid!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Zet niet-PNG iconen in een map om naar transparante PNG en vervang het origineel.")
    parser.add_argument("-d", "--dir", type=str, help="Pad naar de map met iconen")
    parser.add_argument("-t", "--tolerance", type=int, default=40, help="Tolerantie voor kleurschakeringen (standaard 40)")

    args = parser.parse_args()

    # Bepaal het mapproad: via argument of stdin
    target_dir = args.dir

    if not target_dir:
        if not sys.stdin.isatty():
            # Lees pad in vanaf stdin (bijvoorbeeld doorgegeven via piping)
            target_dir = sys.stdin.read().strip()

    if not target_dir:
        print("Fout: Geen map opgegeven via argument (-d) of stdin.")
        sys.exit(1)

    process_directory(target_dir, args.tolerance)

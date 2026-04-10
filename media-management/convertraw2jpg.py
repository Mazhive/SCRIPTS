# convert raw image sequence to jpg by utilizing rawpy
# pip install rawpy
import os
import rawpy
from PIL import Image

def find_lowest_sequence_number(input_dir, start_name):
    crw_files = [f for f in os.listdir(input_dir) if f.startswith(start_name) and f.lower().endswith('.crw')]
    sequence_numbers = [int(f[len(start_name):-4]) for f in crw_files]  # Extract sequence numbers and convert to integers
    return min(sequence_numbers) if sequence_numbers else None

def convert_crw_to_jpg(input_dir, start_name):
    lowest_sequence_number = find_lowest_sequence_number(input_dir, start_name)
    if lowest_sequence_number is None:
        print("No CRW files found.")
        return
    
    crw_files = [f for f in os.listdir(input_dir) if f.startswith(start_name) and f.lower().endswith('.crw')]
    
    for crw_file in crw_files:
        sequence_number = crw_file[len(start_name):-4]  # Extract sequence number from filename
        jpg_filename = f"{start_name}{sequence_number}.jpg"  # Create corresponding jpg filename
        
        crw_path = os.path.join(input_dir, crw_file)
        jpg_path = os.path.join(input_dir, jpg_filename)
        
        with rawpy.imread(crw_path) as raw:
            rgb = raw.postprocess()
            image = Image.fromarray(rgb)
            image.save(jpg_path)
            print(f"Converted {crw_file} to {jpg_filename}")

if __name__ == "__main__":
    input_dir = input("Enter the directory containing CRW files: ")
    start_name = input("Enter the start name for CRW files: ")
    convert_crw_to_jpg(input_dir, start_name)

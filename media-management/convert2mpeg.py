import os
import subprocess

def convert_jpg_sequence_to_mpeg(input_dir, output_file, fps=24):
    jpg_files = [f for f in os.listdir(input_dir) if f.lower().endswith('.jpg')]
    jpg_files.sort()  # Sort the files to ensure correct ordering
    
    if not jpg_files:
        print("No JPG files found in the directory.")
        return
    
    input_pattern = os.path.join(input_dir, '*.jpg')
    
    ffmpeg_cmd = [
        'ffmpeg',
        '-y',  # Overwrite output files without asking
        '-framerate', str(fps),  # Frames per second
        '-pattern_type', 'glob',  # Use glob pattern for input files
        '-i', input_pattern,  # Input pattern for JPG sequence
        '-c:v', 'mpeg4',  # Codec for video compression
        '-q:v', '2',  # Quality for MPEG encoding
        '-r', str(fps),  # Output frame rate
        output_file
    ]
    
    subprocess.run(ffmpeg_cmd)

if __name__ == "__main__":
    input_dir = input("Enter the directory containing JPG sequence files: ")
    output_file = input("Enter the output MPEG file name (with .mp4 extension): ")
    fps = int(input("Enter the frame rate (default is 24): ") or 24)
    convert_jpg_sequence_to_mpeg(input_dir, output_file, fps)

import tkinter as tk
from tkinter import filedialog
import time
import threading

class ShaderPlayer:
    def __init__(self, master):
        self.master = master
        master.title("Shader Player")

        self.speed = 1.0  # Initiële afspeelsnelheid
        self.playing = False
        self.shader_file_path = None

        self.open_button = tk.Button(master, text="Open Shader Example", command=self.open_shader_file)
        self.open_button.pack()

        self.speed_up_button = tk.Button(master, text="Snelheid +", command=self.increase_speed)
        self.speed_up_button.pack()

        self.speed_down_button = tk.Button(master, text="Snelheid -", command=self.decrease_speed)
        self.speed_down_button.pack()

        self.canvas = tk.Canvas(master, width=400, height=300, bg="black")
        self.canvas.pack()

        self.close_button = tk.Button(master, text="Afsluiten", command=master.quit)
        self.close_button.pack()

    def open_shader_file(self):
        self.shader_file_path = filedialog.askopenfilename(
            title="Selecteer een shader voorbeeld bestand",
            filetypes=(("Alle bestanden", "*.*"),)
        )
        if self.shader_file_path:
            print(f"Geselecteerd shader bestand: {self.shader_file_path}")
            # Hier komt de logica om het geselecteerde shader voorbeeld te laden en af te spelen

    def increase_speed(self):
        self.speed *= 1.25
        print(f"Snelheid verhoogd naar: {self.speed}")

    def decrease_speed(self):
        self.speed /= 1.25
        print(f"Snelheid verlaagd naar: {self.speed}")

    def play_shader(self):
        if self.shader_file_path:
            self.playing = True
            while self.playing:
                # Hier komt de logica om het huidige frame van de shader te renderen/tonen
                # Op basis van de 'self.speed' variabele
                time.sleep(0.1 / self.speed) # Eenvoudige vertraging om de snelheid te regelen
                # Voor nu laten we dit leeg, we moeten nog besluiten hoe we de shader gaan weergeven

    def start_playback(self):
        threading.Thread(target=self.play_shader, daemon=True).start()

root = tk.Tk()
player = ShaderPlayer(root)
root.mainloop()

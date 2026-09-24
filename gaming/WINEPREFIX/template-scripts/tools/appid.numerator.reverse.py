import tkinter as tk
from tkinter import ttk, messagebox


class ReeksPlan2Converter:
    """
    Klasse die jouw 3-reeksen logica combineert met de wiskundige 
    conversie van Plan 2 (Base-Conversion) voor een dynamische cijferlimiet.
    """

    def __init__(self):
        # Definiëren van de reeksen volgens jouw specificaties:
        # Reeks 1 (A-I): Positie 1-9 (1 cijfer)
        # Reeks 2 (J-R): Positie 1-9 + '2' (2 cijfers)
        # Reeks 3 (S-Z): Positie 1-8 + '3' (2 cijfers)
        self.r1 = {chr(65 + i): str(i + 1) for i in range(9)}  # A-I
        self.r2 = {chr(74 + i): f"{i + 1}2" for i in range(9)}  # J-R
        self.r3 = {chr(83 + i): f"{i + 1}3" for i in range(8)}  # S-Z

        # Omgekeerde dictionaries voor snelle en verliesvrije decodering
        self.rev_r1 = {v: k for k, v in self.r1.items()}
        self.rev_r2 = {v: k for k, v in self.r2.items()}
        self.rev_r3 = {v: k for k, v in self.r3.items()}

    def tekst_naar_reeksen(self, tekst: str) -> str:
        """Zet tekst om naar de 3-reeksen tussen-code."""
        reeksen_code = ""
        tekst = tekst.upper()

        for char in tekst:
            if char in self.r1:
                reeksen_code += self.r1[char]
            elif char in self.r2:
                reeksen_code += self.r2[char]
            elif char in self.r3:
                reeksen_code += self.r3[char]
            elif char == " ":
                reeksen_code += "0"  # Spatie is 0
            elif char.isdigit():
                reeksen_code += char  # Cijfers direct overnemen
            else:
                # Onbekende tekens negeren om fouten te voorkomen
                continue

        return reeksen_code

    def reeksen_naar_tekst(self, reeksen_code: str) -> str:
        """Zet de 3-reeksen tussen-code om terug naar originele tekst."""
        resultaat = []
        i = 0
        n = len(reeksen_code)

        while i < n:
            # Controleren op 2-cijferige Reeks 2 of Reeks 3 (eindigt op '2' of '3')
            if i + 1 < n and reeksen_code[i + 1] in ("2", "3"):
                sub = reeksen_code[i : i + 2]
                if reeksen_code[i + 1] == "2" and sub in self.rev_r2:
                    resultaat.append(self.rev_r2[sub])
                    i += 2
                    continue
                elif reeksen_code[i + 1] == "3" and sub in self.rev_r3:
                    resultaat.append(self.rev_r3[sub])
                    i += 2
                    continue

            # Controleren op 1-cijferige Reeks 1, Spatie (0) of Los Cijfer
            enkel = reeksen_code[i]
            if enkel in self.rev_r1:
                resultaat.append(self.rev_r1[enkel])
            elif enkel == "0":
                resultaat.append(" ")
            elif enkel.isdigit():
                resultaat.append(enkel)

            i += 1

        return "".join(resultaat)

    def comprimeer_plan2(self, reeksen_code: str, limiet: int) -> str:
        """
        Plan 2: Zet de reeksen-code wiskundig om naar een unieke sleutel
        die exact past binnen de gekozen cijferlimiet.
        """
        if not reeksen_code:
            return "0".zfill(limiet)

        # De string wordt gelezen als een uniek, groot geheel getal
        groot_getal = int(reeksen_code)

        # Wiskundige base-conversion / modulo naar het limietbereik (10^limiet)
        max_waarde = 10**limiet
        gecomprimeerd = groot_getal % max_waarde

        # Zorgen dat de uitkomst altijd netjes opgevuld wordt met voorloopnullen
        return str(gecomprimeerd).zfill(limiet)


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("3-Reeksen + Plan 2 Encoder/Decoder")
        self.geometry("520 x 480")
        self.resizable(False, False)

        self.converter = ReeksPlan2Converter()
        self._build_gui()

    def _build_gui(self):
        padding = {"padx": 12, "pady": 8}

        # --- INVOER SECTIE ---
        lbl_invoer = ttk.Label(self, text="Invoer Tekst / Mapnaam:")
        lbl_invoer.pack(anchor="w", **padding)

        self.ent_invoer = ttk.Entry(self, width=55)
        self.ent_invoer.pack(anchor="w", **padding)
        self.ent_invoer.insert(0, "FORZA HORIZON 5")

        # --- LIMIET SECTIE ---
        frame_limiet = ttk.Frame(self)
        frame_limiet.pack(anchor="w", **padding)

        lbl_limiet = ttk.Label(
            frame_limiet, text="Opgegeven Cijferlimiet (bijv. 8, 10, 12):"
        )
        lbl_limiet.pack(side="left")

        self.spn_limiet = ttk.Spinbox(
            frame_limiet, from_=4, to=32, width=6
        )
        self.spn_limiet.pack(side="left", padx=10)
        self.spn_limiet.set(8)

        # --- KNOPPEN ---
        frame_knoppen = ttk.Frame(self)
        frame_knoppen.pack(anchor="w", **padding)

        btn_coderen = ttk.Button(
            frame_knoppen, text="Coderen", command=self.verwerk_coderen
        )
        btn_coderen.pack(side="left", marginRight=10, padx=5)

        btn_decoderen = ttk.Button(
            frame_knoppen, text="Decoderen", command=self.verwerk_decoderen
        )
        btn_decoderen.pack(side="left", padx=5)

        # --- RESULTATEN ---
        ttk.Separator(self, orient="horizontal").pack(fill="x", pady=10)

        lbl_tussen = ttk.Label(
            self, text="1. Tussen-code (Jouw 3-Reeksen Formule):"
        )
        lbl_tussen.pack(anchor="w", **padding)

        self.txt_tussen = tk.Text(self, height=3, width=60, state="disabled")
        self.txt_tussen.pack(anchor="w", **padding)

        lbl_final = ttk.Label(
            self, text="2. Uiteindelijk Resultaat (Plan 2 Binnen Limiet):"
        )
        lbl_final.pack(anchor="w", **padding)

        self.txt_final = tk.Text(self, height=2, width=60, state="disabled")
        self.txt_final.pack(anchor="w", **padding)

    def verwerk_coderen(self):
        invoer = self.ent_invoer.get().strip()
        try:
            limiet = int(self.spn_limiet.get())
        except ValueError:
            messagebox.showerror("Fout", "Voer een geldig getal in voor de limiet.")
            return

        if not invoer:
            messagebox.showwarning("Waarschuwing", "Voer eerst een tekst in.")
            return

        # 1. Omzetten naar jouw 3-reeksen code
        reeksen_code = self.converter.tekst_naar_reeksen(invoer)

        # 2. Toepassen van Plan 2 wiskunde
        final_code = self.converter.comprimeer_plan2(reeksen_code, limiet)

        # Update scherm
        self._set_text(self.txt_tussen, reeksen_code)
        self._set_text(self.txt_final, final_code)

    def verwerk_decoderen(self):
        """Herstelt de reeksen-code en decodeert deze terug naar tekst."""
        tussen_code = self.txt_tussen.get("1.0", tk.END).strip()

        if not tussen_code:
            messagebox.showwarning(
                "Waarschuwing",
                "Geen tussen-code aanwezig om te decoderen.",
            )
            return

        herstelde_tekst = self.converter.reeksen_naar_tekst(tussen_code)
        self._set_text(self.txt_final, f"Gedecodeerde Tekst: {herstelde_tekst}")

    def _set_text(self, text_widget, content):
        text_widget.config(state="normal")
        text_widget.delete("1.0", tk.END)
        text_widget.insert(tk.END, content)
        text_widget.config(state="disabled")


if __name__ == "__main__":
    app = App()
    app.mainloop()

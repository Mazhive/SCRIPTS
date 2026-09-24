import tkinter as tk
from tkinter import ttk, messagebox

def get_position_digit(position):
    """
    Reduceert een positie-index (bijv. 10, 12, 25) tot 1 enkel cijfer via digitale wortel.
    Bijv: pos 1 -> 1, pos 10 -> 1+0=1, pos 12 -> 1+2=3.
    """
    if position <= 0:
        return 0
    return (position - 1) % 9 + 1

def reduce_sequence_length(digits, target_length):
    """
    Reduceert een lijst met cijfers naar precies target_length items
    door overlappende cijfers op te tellen.
    """
    if target_length <= 0:
        return []
    
    # Als de lijst te kort is, vullen we aan met 0
    if len(digits) < target_length:
        digits = digits + [0] * (target_length - len(digits))
        return digits

    # Als de lijst te lang is, reduceren we vouwend/optellend tot het gewenste aantal
    result = list(digits)
    while len(result) > target_length:
        last_val = result.pop()
        idx = (len(result)) % target_length
        sum_val = result[idx] + last_val
        
        if sum_val == 0:
            result[idx] = 0
        else:
            result[idx] = (sum_val - 1) % 9 + 1

    return result

def process_text():
    raw_text = entry_text.get()
    try:
        target_len = int(entry_length.get())
        if target_len <= 0:
            raise ValueError
    except ValueError:
        messagebox.showerror("Fout", "Voer een geldig positief getal in voor de gewenste lengte.")
        return

    # 1. Omzetten op basis van POSITIE in de tekst
    digits = []
    step_details = []
    
    position_counter = 1
    
    for char in raw_text:
        if char == ' ':
            digits.append(0)
            step_details.append("[SPATIE](0)")
            position_counter += 1
        elif char.isalpha():
            digit = get_position_digit(position_counter)
            digits.append(digit)
            if position_counter > 9:
                step_details.append(f"{char.upper()}(pos {position_counter}→{digit})")
            else:
                step_details.append(f"{char.upper()}(pos {position_counter}={digit})")
            position_counter += 1

    if not digits:
        lbl_result.config(text="Geen letters of spaties gevonden in de invoer.")
        lbl_details.config(text="")
        return

    # 2. Reduceer de reeks naar de gewenste lengte
    reduced_digits = reduce_sequence_length(digits, target_len)
    result_str = "".join(map(str, reduced_digits))

    # Resultaten weergeven
    lbl_result.config(text=f"Eindresultaat ({len(result_str)} cijfers):\n{result_str}")
    lbl_details.config(text=f"Positie-omzetting: {' '.join(step_details)}\n"
                           f"Oorspronkelijke cijferreeks ({len(digits)} lang): {''.join(map(str, digits))}")

# GUI Opzetten
root = tk.Tk()
root.title("Tekst naar Cijfers Reductie App")
root.geometry("540x440")
root.resizable(False, False)

# Styling
style = ttk.Style()
style.theme_use('clam')

frame = ttk.Frame(root, padding="20")
frame.pack(fill=tk.BOTH, expand=True)

# Invoerveld Tekst
lbl_text = ttk.Label(frame, text="Voer je tekst in:", font=('Helvetica', 10, 'bold'))
lbl_text.pack(anchor=tk.W, pady=(0, 5))

entry_text = ttk.Entry(frame, width=50, font=('Helvetica', 11))
entry_text.pack(fill=tk.X, pady=(0, 15))
entry_text.insert(0, "Hello World")

# Invoerveld Gewenste Lengte
lbl_length = ttk.Label(frame, text="Gewenste aantal cijfers (bijv. 8):", font=('Helvetica', 10, 'bold'))
lbl_length.pack(anchor=tk.W, pady=(0, 5))

entry_length = ttk.Entry(frame, width=15, font=('Helvetica', 11))
entry_length.pack(anchor=tk.W, pady=(0, 20))
entry_length.insert(0, "8")

# Knop
btn_convert = ttk.Button(frame, text="Omzetten en Reduceren", command=process_text)
btn_convert.pack(fill=tk.X, ipady=5, pady=(0, 20))

# Resultaatweergave
lbl_result = ttk.Label(frame, text="", font=('Helvetica', 14, 'bold'), foreground="#2b5c8f", justify=tk.CENTER)
lbl_result.pack(pady=(0, 10))

lbl_details = ttk.Label(frame, text="", font=('Helvetica', 9), foreground="#555555", justify=tk.CENTER, wraplength=480)
lbl_details.pack()

# Start applicatie
root.mainloop()

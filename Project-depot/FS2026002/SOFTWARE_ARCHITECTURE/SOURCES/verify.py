def verify_alignment(soft_file, hard_file):
    with open(soft_file, "r") as f_s, open(hard_file, "r") as f_h:
        next(f_s) # Skip header
        for i, (line_s, line_h) in enumerate(zip(f_s, f_h)):
            actual_s = line_s.strip().split(",")[1]
            if "A:" in line_h:
                actual_h = line_h.split("A:")[1].strip()
                if actual_s != actual_h:
                    print(f"ERROR at Index {i}: Soft={actual_s}, Hard={actual_h}")
                    return
    print("SUCCESS: Hardware and Software indices are perfectly aligned.")

if __name__ == "__main__":
    verify_alignment("../RESULTS/software_mapping.txt", "hardware_predictions.txt")
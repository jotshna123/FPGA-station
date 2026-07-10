import os
import shutil
import numpy as np

import SOURCES.config as config

from SOURCES.clause_outputs import get_clause_outputs
from SOURCES.clause_weights import get_clause_weights

# ==========================================================
# DATASET-SPECIFIC RESULTS FOLDER
# ==========================================================

RESULTS_DIR = os.path.abspath(
    config.OUTPUT_FOLDER
)

os.makedirs(
    RESULTS_DIR,
    exist_ok=True
)

print(f"\nResults Folder : {RESULTS_DIR}")


def save_clause_inputs(clause_inputs):
    print("Writing clause inputs to hardware memory files...")
    half_clauses = len(clause_inputs) // 2

    with open(f"{RESULTS_DIR}/clauses_A.mem", "w") as f:
        for clause in clause_inputs[:half_clauses]:
            f.write("".join(map(str, clause)) + "\n")

    with open(f"{RESULTS_DIR}/clauses_B.mem", "w") as f:
        for clause in clause_inputs[half_clauses:]:
            f.write("".join(map(str, clause)) + "\n")

    print(" -> Success! Wrote clauses_A.mem and clauses_B.mem")


def save_clause_weights(weight_banks):

    print("Writing clause_weights.mem...")

    with open(f"{RESULTS_DIR}/clause_weights.mem", "w") as f:

        for class_id in range(len(weight_banks)):
            for w in weight_banks[class_id]:

                binary_weight = format(
                    int(w) & 0xFFFF,
                    "016b"
                )

                f.write(binary_weight + "\n")

    print(" -> Success!")


def save_encoded_test_vectors(dataset_name, expected_clause_width):
    print("\nEncoding Test Vectors for Vivado...")
    dataset_path = os.path.abspath(
    os.path.join(
        os.path.dirname(__file__),
        "..",
        "DATASET",
        dataset_name.strip()
    )
)
    x_test_path  = os.path.join(dataset_path, "x_test.txt")
    y_test_path  = os.path.join(dataset_path, "y_test.txt")

    if os.path.exists(x_test_path):
        x_raw = np.loadtxt(x_test_path, dtype=int, ndmin=2)
        num_vectors = len(x_raw)

        with open(f"{RESULTS_DIR}/x_test_encoded.mem", "w") as f:
            for row in x_raw:
                if len(row) == expected_clause_width:
                    f.write("".join(str(bit) for bit in row) + "\n")
                else:
                    original_bits   = "".join(str(bit) for bit in row)
                    complement_bits = "".join(str(1 - bit) for bit in row)
                    f.write(original_bits + complement_bits + "\n")

        print(f" -> Success! 'x_test_encoded.mem' generated with {num_vectors} rows.")

        vh_path = f"{RESULTS_DIR}/tm_params.vh"
        if os.path.exists(vh_path):
            with open(vh_path, "a") as f:
                f.write(f"\n// Automatically counted test vectors from Python\n")
                f.write(f"`define NUM_TEST_VECTORS {num_vectors}\n")
            print(f" -> Success! Injected `define NUM_TEST_VECTORS {num_vectors} into tm_params.vh")

    else:
        print(f" -> ERROR: Could not find '{x_test_path}' to encode.")

    # ==================================================================
    # FIX: Copy y_test.txt into RESULTS so Vivado $readmemb can find it
    # Without this, r_actual_class_mem stays 'x' (unknown) in simulation
    # ==================================================================
    if os.path.exists(y_test_path):
        shutil.copy(
    y_test_path,
    os.path.join(
        RESULTS_DIR,
        "y_test.txt"
    )
)
        print(f" -> Success! Copied y_test.txt to RESULTS/")
    else:
        print(f" -> ERROR: Could not find '{y_test_path}' to copy.")


def verify_generated_files(num_test_vectors):
    print("\n=======================================================")
    print("   HARDWARE FILE VERIFICATION")
    print("=======================================================")

    required_files = [
        "tm_params.vh",
        "clauses_A.mem",
        "clauses_B.mem",
        "clause_weights.mem",
        "x_test_encoded.mem",
        "y_test.txt",              # now checked here too
        "python_class_sums.csv"
    ]

    all_passed = True
    for filename in required_files:
        filepath = os.path.join(
    RESULTS_DIR,
    filename
)
        if os.path.exists(filepath):
            size = os.path.getsize(filepath)
            if size > 0:
                print(f"[PASS] {filename} exists ({size} bytes).")
            else:
                print(f"[FAIL] {filename} exists but is EMPTY (0 bytes).")
                all_passed = False
        else:
            print(f"[FAIL] {filename} is MISSING.")
            all_passed = False

    if all_passed:
        print("-> Verification Successful! All hardware files are ready for Vivado.")
    else:
        print("-> WARNING: Verification failed. Check file generation logs.")
    print("=======================================================\n")


def save_python_class_sums(tm, x_test, num_classes, num_clauses, best_weight_banks=None):
    """
    Replicates hardware AND logic exactly using .mem files directly.
    Does NOT use tm.transform() — reads same files as Vivado.
    """
    print("\nCalculating Python Class Sums (Hardware-Exact .mem replication)...")

    # Load encoded test vectors — exact same file Vivado loads
    enc_lines = [l.strip() for l in open(f"{RESULTS_DIR}/x_test_encoded.mem")
                 if l.strip()]
    print(f"  Loaded {len(enc_lines)} encoded test vectors from x_test_encoded.mem")

    # Load clause banks — exact same files Vivado loads
    half      = num_clauses // 2
    clauses_A = [l.strip() for l in open(f"{RESULTS_DIR}/clauses_A.mem")  if l.strip()]
    clauses_B = [l.strip() for l in open(f"{RESULTS_DIR}/clauses_B.mem")  if l.strip()]
    print(f"  Loaded {len(clauses_A)} clauses from clauses_A.mem")
    print(f"  Loaded {len(clauses_B)} clauses from clauses_B.mem")

    # Load weights — exact same file Vivado loads, decoded as signed 16-bit
    wt_lines = [l.strip() for l in open(f"{RESULTS_DIR}/clause_weights.mem") if l.strip()]
    vivado_weights = []
    for line in wt_lines:
        val = int(line, 2)
        if val >= 32768:
            val -= 65536
        vivado_weights.append(val)
    vivado_weights = np.array(vivado_weights).reshape(num_classes, num_clauses)
    print("\nLoaded Weights")
    for c in range(num_classes):
        print(f"\nClass {c} Weights")
        print(vivado_weights[c])
    print(f"  Loaded weights: shape {vivado_weights.shape}, "
          f"min={vivado_weights.min()}, max={vivado_weights.max()}")

    # Replicate clause_output_predict AND logic exactly
    def evaluate_clause(clause_bits, x_bits):
        for i in range(len(clause_bits)):
            if clause_bits[i] == '1' and x_bits[i] == '0':
                return 0
        return 1

    # DEBUG: show clause activations for first test vector
    first_acts = []
    for g in range(num_clauses):
        cb = clauses_A[g] if g < half else clauses_B[g - half]
        first_acts.append(evaluate_clause(cb, enc_lines[0]))
    first_acts = np.array(first_acts, dtype=int)
    print(f"\n  [DEBUG] Test_Vector_0 clause activations sum : {first_acts.sum()}")
    for c in range(num_classes):
        cs = int(np.dot(first_acts, vivado_weights[c]))
        print(f"  [DEBUG] Test_Vector_0 Class{c}_Sum           : {cs}")

    # Write CSV
    with open(f"{RESULTS_DIR}/python_class_sums.csv", "w") as f_csv:
        header = ["Index"] + [f"Class{c}_Sum" for c in range(num_classes)]
        f_csv.write(",".join(header) + "\n")

        for i, x_enc in enumerate(enc_lines):
            clause_acts = []
            for g in range(num_clauses):
                cb = clauses_A[g] if g < half else clauses_B[g - half]
                clause_acts.append(evaluate_clause(cb, x_enc))

            clause_acts = np.array(clause_acts, dtype=int)
            c_sums = [str(int(np.dot(clause_acts, vivado_weights[c])))
                      for c in range(num_classes)]
            f_csv.write(",".join([str(i)] + c_sums) + "\n")

    print(f"\n -> Success! Wrote {len(enc_lines)} rows to python_class_sums.csv")


# ---------------------------------------------------------
# Stubs for secondary files
# ---------------------------------------------------------
def save_class_sums(class_sums): pass
def save_prediction(actual_class, predicted_class): pass
def save_metrics(results): pass
def save_summary(actual_class, predicted_class, active_clauses, accuracy): pass

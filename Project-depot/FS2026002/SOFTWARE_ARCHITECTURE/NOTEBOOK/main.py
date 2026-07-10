import sys
import os
import logging
import numpy as np

sys.path.append(
    os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            ".."
        )
    )
)

from SOURCES.dataset import load_dataset
from SOURCES.trainer import create_tm
from SOURCES.config import *

from SOURCES.clause_inputs import get_clause_inputs
from SOURCES.clause_outputs import get_clause_outputs
from SOURCES.clause_weights import get_clause_weights
from SOURCES.class_sums import get_class_sums
from SOURCES.prediction import get_prediction

from SOURCES.metrics import (
    get_positive_clauses,
    get_number_of_includes
)

from SOURCES.result_writer import (
    save_clause_inputs,
    save_clause_weights,
    save_encoded_test_vectors,
    save_class_sums,
    save_prediction,
    save_metrics,
    save_summary,
    verify_generated_files,
    save_python_class_sums
)

from SOURCES.verilog_header import (
    generate_verilog_header
)

from tmu.tools import BenchmarkTimer

logging.basicConfig(level=logging.INFO)
_LOGGER = logging.getLogger(__name__)


def main():
    results = {
        "accuracy": [],
        "number_of_positive_clauses": [],
        "number_of_includes": []
    }

    data = load_dataset()
    tm = create_tm()

    _LOGGER.info(f"Running {DATASET_NAME} {NUM_CLAUSES}-Clause Binary Classifier for {EPOCHS} epochs")

    best_overall_accuracy = 0.0
    best_clause_inputs    = None
    best_weights          = None
    best_epoch_num        = 0
    best_weight_banks     = None

    for epoch in range(EPOCHS):
        benchmark_train = BenchmarkTimer()
        with benchmark_train:
            tm.fit(data["x_train"], data["y_train"])

        benchmark_test = BenchmarkTimer()
        with benchmark_test:
            accuracy = 100 * (tm.predict(data["x_test"]) == data["y_test"]).mean()

        positive_clauses = get_positive_clauses(tm)
        includes         = get_number_of_includes(tm, NUM_CLAUSES)

        results["accuracy"].append(accuracy)
        results["number_of_positive_clauses"].append(positive_clauses)
        results["number_of_includes"].append(includes)

        _LOGGER.info(f"Epoch: {epoch+1}, Accuracy: {accuracy:.2f}")

        if accuracy > best_overall_accuracy:
            best_overall_accuracy = accuracy
            best_epoch_num        = epoch + 1
            best_clause_inputs    = get_clause_inputs(tm)
            best_weights          = get_clause_weights(tm)
            best_weight_banks     = [
                tm.weight_banks[c].get_weights().copy()
                for c in range(NUM_CLASSES)
            ]

    # =====================================================================
    # Post-training export
    # =====================================================================
    x_test_safe = np.atleast_2d(data["x_test"])
    y_test_safe = np.atleast_1d(data["y_test"])

    sample          = np.atleast_2d(x_test_safe[SAMPLE_INDEX])
    actual_class    = y_test_safe[SAMPLE_INDEX]
    clause_outputs  = get_clause_outputs(tm, sample)
    class_sums      = get_class_sums(tm, clause_outputs)
    predicted_class = get_prediction(tm, sample)
    active_clauses  = clause_outputs.sum()

    print("\n=======================================================")
    print(f"Exporting Hardware for Best Epoch: {best_epoch_num} ({best_overall_accuracy:.2f}%)")
    print("=======================================================")

    generate_verilog_header()
    save_clause_inputs(best_clause_inputs)
    save_clause_weights(best_weight_banks)
    print("\nTM Weights")
    print(best_weight_banks[0])

    print(best_weight_banks[1])

    expected_width = len(best_clause_inputs[0])
    save_encoded_test_vectors(DATASET_NAME, expected_width)

    save_class_sums(class_sums)
    save_prediction(actual_class, predicted_class)
    save_metrics(results)
    save_summary(actual_class, predicted_class, active_clauses, results["accuracy"][-1])
    save_python_class_sums(tm, x_test_safe, NUM_CLASSES, NUM_CLAUSES, best_weight_banks)

    num_test_vectors = len(x_test_safe)
    verify_generated_files(num_test_vectors)

    # =====================================================================
    # Save python_prediction_mapping.csv
    # =====================================================================
    import SOURCES.config as config

    results_dir = config.OUTPUT_FOLDER
    csv_path     = os.path.join(results_dir, "python_class_sums.csv")
    mapping_path = os.path.join(results_dir, "python_prediction_mapping.csv")

    print("\n=======================================================")
    print("   SAVING PYTHON PREDICTION MAPPING")
    print("=======================================================")

    with open(csv_path) as f_in, open(mapping_path, "w") as f_out:
        f_out.write("Index,Actual_Class,Predicted_Class,Correct\n")
        next(f_in)
        for line in f_in:
            parts     = line.strip().split(",")
            idx       = int(parts[0])
            sums      = [int(x) for x in parts[1:]]
            predicted = sums.index(max(sums))
            actual    = int(y_test_safe[idx])
            correct   = 1 if predicted == actual else 0
            f_out.write(f"{idx},{actual},{predicted},{correct}\n")

    correct_count = 0
    total         = 0
    with open(mapping_path) as f:
        next(f)
        for line in f:
            parts = line.strip().split(",")
            if len(parts) == 4:
                correct_count += int(parts[3])
                total         += 1

    print(f" -> Saved {total} rows")
    print(f" -> Accuracy from mapping : {100*correct_count/total:.2f}%  "
          f"(should match {best_overall_accuracy:.2f}%)")
    if abs(100*correct_count/total - best_overall_accuracy) < 1.0:
        print(" -> [OK] Clause extraction is correct!")
    else:
        print(" -> [!!] Still mismatch — clause_inputs.py needs further fix.")
    print("=======================================================\n")

    print("\n=======================================================")
    print("   TRAINING SUMMARY")
    print("=======================================================")
    print(f"Highest Accuracy : {best_overall_accuracy:.2f}%")
    print(f"Best Epoch       : Epoch {best_epoch_num}")
    print("=======================================================\n")


if __name__ == "__main__":
    __spec__ = None
    main()
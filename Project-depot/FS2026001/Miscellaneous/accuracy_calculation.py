import numpy as np

# =====================================================
# PARAMETERS
# =====================================================

NUM_CLASSES = 7
NUM_TEST_SAMPLES = 2500
NUM_LITERALS = 134

CLASS_CLAUSES = [
    64, 96, 54, 68, 189, 200, 178
]

TOTAL_CLAUSES = sum(CLASS_CLAUSES)

# =====================================================
# LOAD CLAUSES
# =====================================================

print("Loading clauses...")

clauses = []

with open("covertype/pruned_clauses.mem", "r") as f:
    for line in f:
        line = line.strip()

        if line:
            clauses.append(
                [int(b) for b in line]
            )

clauses = np.array(
    clauses,
    dtype=np.uint8
)

print("Clauses shape =", clauses.shape)

# =====================================================
# LOAD WEIGHTS
# =====================================================

print("Loading weights...")

weights = []

with open("covertype/pruned_weights.mem", "r") as f:
    for line in f:

        value = int(
            line.strip(),
            2
        )

        if value >= 128:
            value -= 256

        weights.append(value)

weights = np.array(
    weights,
    dtype=np.int16
)

print("Weights shape =", weights.shape)

# =====================================================
# LOAD TEST VECTORS
# =====================================================

print("Loading test vectors...")

test_vectors = []

with open("covertype/pruned_x_2500.mem", "r") as f:
    for line in f:

        line = line.strip()

        if line:
            test_vectors.append(
                [int(b) for b in line]
            )

test_vectors = np.array(
    test_vectors,
    dtype=np.uint8
)

print(
    "Test vectors shape =",
    test_vectors.shape
)

# =====================================================
# LOAD LABELS
# =====================================================

print("Loading labels...")

labels = []

with open("covertype/pruned_y_2500.mem", "r") as f:
    for line in f:
        labels.append(
            int(
                line.strip(),
                2
            )
        )

labels = np.array(labels)

print(
    "Labels shape =",
    labels.shape
)

# =====================================================
# VERIFY
# =====================================================

assert clauses.shape == (
    TOTAL_CLAUSES,
    NUM_LITERALS
)

assert len(weights) == TOTAL_CLAUSES

assert test_vectors.shape == (
    NUM_TEST_SAMPLES,
    NUM_LITERALS
)

assert len(labels) == NUM_TEST_SAMPLES

print("\nAll checks PASSED")

# =====================================================
# BUILD OFFSETS
# =====================================================

offsets = [0]

for count in CLASS_CLAUSES:
    offsets.append(
        offsets[-1] + count
    )

print("Offsets =", offsets)

# =====================================================
# CLASSIFICATION
# =====================================================

correct_count = 0

for sample in range(NUM_TEST_SAMPLES):

    x = test_vectors[sample]

    scores = np.zeros(
        NUM_CLASSES,
        dtype=np.int32
    )

    for cls in range(NUM_CLASSES):

        start = offsets[cls]
        end = offsets[cls + 1]

        score = 0

        for idx in range(start, end):

            clause = clauses[idx]

            # Empty clause does not vote
            if np.sum(clause) == 0:
                vote = False
            else:
                vote = np.all(
                    x[clause == 1] == 1
                )

            if vote:
                score += weights[idx]

        scores[cls] = score

    prediction = np.argmax(scores)

    if prediction == labels[sample]:
        correct_count += 1

    print(
        f"Sample {sample:03d} | "
        f"Pred={prediction} | "
        f"Label={labels[sample]} | "
        f"Correct={correct_count}"
    )

# =====================================================
# RESULTS
# =====================================================

accuracy = (
    correct_count /
    NUM_TEST_SAMPLES
) * 100.0

print("\n")
print("=" * 60)
print("FINAL RESULTS")
print("=" * 60)
print("Correct Samples :", correct_count)
print("Total Samples   :", NUM_TEST_SAMPLES)
print("Accuracy (%)    :", accuracy)
print("=" * 60)
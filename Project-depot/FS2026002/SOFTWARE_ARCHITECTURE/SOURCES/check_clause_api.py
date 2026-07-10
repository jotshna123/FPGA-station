from tmu.data import MNIST
from tmu.models.classification.coalesced_classifier import (
    TMCoalescedClassifier
)

data = MNIST().get()

tm = TMCoalescedClassifier(
    number_of_clauses=10,
    T=10,
    s=10.0
)

tm.fit(
    data["x_train"],
    data["y_train"]
)

print(dir(tm))

print("\n\n")

print(dir(tm.clause_bank))
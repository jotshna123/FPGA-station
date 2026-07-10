import numpy as np


def get_class_sums(
        tm,
        clause_outputs
):

    class_sums = {}

    for class_id in range(
            tm.number_of_classes
    ):

        weights = (
            tm.weight_banks[class_id]
            .get_weights()
        )

        class_sum = np.sum(
            weights * clause_outputs
        )

        class_sums[class_id] = (
            int(class_sum)
        )

    return class_sums
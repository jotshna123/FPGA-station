import numpy as np


def get_clause_outputs(
        tm,
        sample
):

    clause_outputs = []

    for clause_id in range(
            tm.number_of_clauses
    ):

        try:

            value = tm.clause_bank.calculate_clause_output(
                clause_id,
                sample
            )

        except:

            value = 0

        clause_outputs.append(
            int(value)
        )

    return np.array(
        clause_outputs
    )
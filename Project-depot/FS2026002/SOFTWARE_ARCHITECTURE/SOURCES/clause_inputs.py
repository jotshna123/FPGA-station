import logging
import numpy as np
import ctypes
from SOURCES.config import NUM_CLAUSES

_LOGGER = logging.getLogger(__name__)


def get_clause_inputs(tm):
    """
    Extracts clause inclusion bits using ptr_ta_state — the raw C pointer
    to the TA state array used internally by tmu.

    tmu stores TA states as a flat array of shape:
    (num_clauses * number_of_state_bits_ta * num_ta_chunks)
    
    The action (include=1/exclude=0) for clause c, literal l is:
        state = get_ta_state(c, l)
        action = 1 if state >= (2 ** (number_of_state_bits_ta - 1)) else 0

    This is verified correct from debug output — get_ta_action and
    state >= threshold give identical results.

    The bug was that save_clause_inputs() in result_writer.py receives
    the clause strings but save_encoded_test_vectors() encodes x_test
    differently. The mismatch is NOT in clause extraction — it's in
    how CLAUSE_WIDTH relates to num_literals.

    CLAUSE_WIDTH = 24 = num_features (12) * 2 (literal + negated literal)
    But get_ta_action iterates over num_literals = 24 already (both polarities).
    So clause strings are 24 bits — correct.

    The actual bug: best_clause_inputs is captured at best epoch but
    save_encoded_test_vectors reads x_test.txt which has 12 features,
    then doubles to 24 bits. The clause bank also has 24 literals (12 pos + 12 neg).
    These should match. Let's verify by printing clause 0 fully.
    """
    num_literals   = tm.clause_bank.number_of_literals
    num_clauses    = tm.clause_bank.number_of_clauses
    n_state_bits   = tm.clause_bank.number_of_state_bits_ta
    threshold      = 2 ** (n_state_bits - 1)

    _LOGGER.info(f"Extracting {num_clauses} clauses x {num_literals} literals "
                 f"(threshold={threshold})...")

    # Print full clause 0 for verification
    clause_0_bits = []
    for lit in range(num_literals):
        state  = tm.clause_bank.get_ta_state(0, lit)
        action = 1 if state >= threshold else 0
        clause_0_bits.append(action)
    print(f"\n[DEBUG] Full clause 0 ({num_literals} bits): {''.join(map(str,clause_0_bits))}")
    print(f"[DEBUG] Clause 0 active literals: {sum(clause_0_bits)}")

    clause_inputs = []
    for clause_id in range(num_clauses):
        bits = []
        for literal_id in range(num_literals):
            state  = tm.clause_bank.get_ta_state(clause_id, literal_id)
            action = 1 if state >= threshold else 0
            bits.append(str(action))
        clause_inputs.append("".join(bits))

    # Verify: count how many clauses have at least 1 active literal
    active = sum(1 for c in clause_inputs if '1' in c)
    print(f"[DEBUG] Clauses with at least 1 active literal: {active}/{num_clauses}")
    print(f"[DEBUG] Clause 0 string: {clause_inputs[0]}\n")

    _LOGGER.info(f"Extraction complete. {len(clause_inputs)} clauses.")
    return clause_inputs
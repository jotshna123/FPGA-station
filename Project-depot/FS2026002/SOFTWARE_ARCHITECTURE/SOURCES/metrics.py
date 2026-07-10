import numpy as np
import SOURCES.config as config

def get_positive_clauses(tm):
    positive_count = 0
    for j in range(config.NUM_CLAUSES):
        # Scan weights matrix lists across your active class boundaries safely
        if np.abs(tm.get_weight(0, j)) > 0 or np.abs(tm.get_weight(1, j)) > 0:
            positive_count += 1
    return positive_count


def get_number_of_includes(tm, num_clauses):
    total_includes = 0
    for clause_idx in range(num_clauses):
        for feature_idx in range(config.CLAUSE_WIDTH):
            try:
                if tm.get_state(clause_idx, feature_idx) >= 0:
                    total_includes += 1
            except Exception:
                break
    return total_includes
def get_clause_weights(tm):
    """
    Extracts all weights directly from the Tsetlin Machine and 
    returns them as a single, flat list of integers.
    """
    raw_weights = []
    
    for class_id in range(tm.number_of_classes):
        for clause_id in range(tm.number_of_clauses):
            # Grab the exact integer weight for this specific class and clause
            single_weight = tm.get_weight(class_id, clause_id)
            raw_weights.append(single_weight)
            
    return raw_weights
input_mem = "covertype/pruned_y_2500.mem" # input file path
output_coe = "covertype/pruned_y_2500.coe" # output file path 

with open(input_mem, "r") as fin:
    lines = [line.strip() for line in fin if line.strip()]

with open(output_coe, "w") as fout:
    fout.write("memory_initialization_radix=2;\n")
    fout.write("memory_initialization_vector=\n")

    for i, line in enumerate(lines):
        if i == len(lines) - 1:
            fout.write(line + ";\n")
        else:
            fout.write(line + ",\n")

print(f"Generated {output_coe}")
print(f"Total clauses = {len(lines)}")
print(f"Clause width  = {len(lines[0])} bits")

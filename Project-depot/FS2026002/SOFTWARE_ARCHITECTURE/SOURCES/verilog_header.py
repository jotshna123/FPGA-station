import os
import logging
import SOURCES.config as config

_LOGGER = logging.getLogger(__name__)

def generate_verilog_header():

    os.makedirs(
        config.OUTPUT_FOLDER,
        exist_ok=True
    )

    output_path = os.path.join(
        config.OUTPUT_FOLDER,
        "tm_params.vh"
    )

    _LOGGER.info(
        f"Generating Verilog header at: {output_path}"
    )

    with open(output_path, "w") as f:

        f.write("// =====================================================================\n")
        f.write(f"// AUTO-GENERATED PARAMS HEADER FOR DATASET: {config.DATASET_NAME}\n")
        f.write("// =====================================================================\n\n")

        f.write(f"`define CLAUSE_WIDTH      {config.CLAUSE_WIDTH}\n")
        f.write(f"`define NUM_CLASSES       {config.NUM_CLASSES}\n")
        f.write(f"`define NUM_CLAUSES       {config.NUM_CLAUSES}\n")
        f.write(f"`define T_VALUE           {int(config.T)}\n\n")
        f.write(f"`define NUM_FEATURES       {config.NUM_FEATURES}\n")
        f.write(f"`define NUMBER_OF_STATES  {config.NUMBER_OF_STATES}\n")

        f.write("// Block RAM Parameters\n")
        f.write(f"`define BRAM_DEPTH        {config.VIVADO_CLAUSES_PER_BANK}\n")

    print(f"-> Successfully updated: {output_path}")
# =====================================================================
# HARDWARE CO-DESIGN CONFIGURATION PROFILE (NOISYXOR)
# =====================================================================
DATASET_NAME = "NOISYXOR"      

EPOCHS = 200             
T = 15                    
S = 3.9                    

# Core Hardware Geometry (Explicitly scaled for NOISYXOR)
NUM_FEATURES = 12           
NUM_CLASSES = 2         
NUM_CLAUSES = 20      
NUMBER_OF_CLAUSES = 20
NUMBER_OF_STATES=100

CLAUSE_WIDTH = 24           # 784 features * 2 = 1568 bits + 2 padding bits
VIVADO_BUS_WIDTH = 24      
VIVADO_CLAUSES_PER_BANK = 100  # Slices your 200 clauses into 10 lines per file

# Advanced Pipeline Configurations
PLATFORM = "CPU"
WEIGHTED_CLAUSES = True
FOCUSED_NEGATIVE_SAMPLING = True
SAMPLE_INDEX = 0
import os

OUTPUT_FOLDER = os.path.join(
    "../RESULTS",
    DATASET_NAME
)
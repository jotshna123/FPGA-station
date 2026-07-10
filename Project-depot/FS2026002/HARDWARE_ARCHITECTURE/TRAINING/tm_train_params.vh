`ifndef TM_TRAIN_PARAMS_VH
`define TM_TRAIN_PARAMS_VH

//=====================================================
// Dataset Parameters
//=====================================================
`define NUM_FEATURES          12
`define NUM_LITERALS          (`NUM_FEATURES * 2)

`define NUM_CLASSES           2
`define NUM_CLAUSES           20

`define TRAIN_SAMPLES         5
`define TEST_SAMPLES          5
`define WEIGHT_MAX            127
`define WEIGHT_MIN            -127

//=====================================================
// Tsetlin Machine Parameters
//=====================================================
`define NUMBER_OF_STATES      100
`define STATE_BITS            7

// TA States
`define STATE_MIN             1
`define STATE_MAX             100
`define INITIAL_TA_STATE      50

// Clause Weights
`define INITIAL_WEIGHT        16'sd1

// Learning Parameters
`define THRESHOLD_T           15
`define S_VALUE               3.9

// Hardware probability thresholds
// reward  ≈ (S-1)/S  ≈ 190/256
// penalty ≈ 1/S      ≈ 66/256
`define REWARD_THRESHOLD      8'd190
`define PENALTY_THRESHOLD     8'd66

//=====================================================
// Training Parameters
//=====================================================
`define EPOCHS                50

//=====================================================
// Memory Sizes
//=====================================================
`define TOTAL_TAS             (`NUM_CLAUSES * `NUM_LITERALS)
`define TOTAL_WEIGHTS         (`NUM_CLASSES * `NUM_CLAUSES)

//=====================================================
// Address Widths
//=====================================================
`define CLAUSE_BITS           5
`define LITERAL_BITS          5
`define CLASS_BITS            4

//=====================================================
// Counter Widths
//=====================================================
`define SAMPLE_COUNTER_BITS   16
`define EPOCH_COUNTER_BITS    8

//=====================================================
// Miscellaneous
//=====================================================
`define SAMPLE_BITS           16

`endif
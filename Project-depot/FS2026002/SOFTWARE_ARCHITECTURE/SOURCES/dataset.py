import os
import logging
import numpy as np
import SOURCES.config as config

_LOGGER = logging.getLogger(__name__)


# ============================================================
# CHECK IF DATASET FILES EXIST
# ============================================================

def dataset_files_exist(folder_path):

    required = [
        "x_train.txt",
        "y_train.txt",
        "x_test.txt",
        "y_test.txt"
    ]

    return all(
        os.path.exists(
            os.path.join(folder_path, f)
        )
        for f in required
    )


# ============================================================
# MNIST AUTO GENERATOR
# ============================================================

def generate_mnist_dataset(folder_path):

    from sklearn.datasets import fetch_openml

    print("\n=======================================================")
    print("Generating Binary MNIST Dataset")
    print("=======================================================")

    mnist = fetch_openml(
        "mnist_784",
        version=1,
        as_frame=False
    )

    x = mnist.data.astype(np.uint8)
    y = mnist.target.astype(np.uint8)

    # Binary threshold
    x = (x > 75).astype(np.uint8)

    x_train = x[:60000]
    y_train = y[:60000]

    x_test = x[60000:]
    y_test = y[60000:]

    os.makedirs(folder_path, exist_ok=True)

    np.savetxt(
        os.path.join(folder_path, "x_train.txt"),
        x_train,
        fmt="%d"
    )

    np.savetxt(
        os.path.join(folder_path, "y_train.txt"),
        y_train,
        fmt="%d"
    )

    np.savetxt(
        os.path.join(folder_path, "x_test.txt"),
        x_test,
        fmt="%d"
    )

    np.savetxt(
        os.path.join(folder_path, "y_test.txt"),
        y_test,
        fmt="%d"
    )

    print("MNIST dataset generated successfully.")

    return {
        "x_train": x_train,
        "y_train": y_train,
        "x_test": x_test,
        "y_test": y_test
    }


# ============================================================
# AUTO GENERATOR ROUTER
# ============================================================

def auto_generate_dataset(dataset_name, folder_path):

    dataset_name = dataset_name.upper()

    if dataset_name == "MNIST":
        return generate_mnist_dataset(folder_path)

    raise RuntimeError(
        f"No automatic generator available for "
        f"dataset '{dataset_name}'"
    )


# ============================================================
# MAIN LOADER
# ============================================================

def load_dataset():

    base_dataset_dir = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "..",
            "DATASET"
        )
    )

    dataset_name = config.DATASET_NAME.strip()

    folder_path = os.path.join(
        base_dataset_dir,
        dataset_name
    )

    print("\n=======================================================")
    print(f"Loading Dataset : {dataset_name}")
    print("=======================================================")

    # --------------------------------------------------------
    # AUTO GENERATE IF FILES DON'T EXIST
    # --------------------------------------------------------

    if not dataset_files_exist(folder_path):

        print("\nDataset files not found.")

        try:

            return auto_generate_dataset(
                dataset_name,
                folder_path
            )

        except Exception as e:

            raise RuntimeError(
                f"\nCannot generate dataset '{dataset_name}'.\n"
                f"Please provide:\n"
                f"x_train.txt\n"
                f"y_train.txt\n"
                f"x_test.txt\n"
                f"y_test.txt\n\n"
                f"Reason:\n{e}"
            )

    # --------------------------------------------------------
    # LOAD EXISTING FILES
    # --------------------------------------------------------

    x_train = np.loadtxt(
        os.path.join(folder_path, "x_train.txt"),
        dtype=int
    )

    y_train = np.loadtxt(
        os.path.join(folder_path, "y_train.txt"),
        dtype=int
    )

    x_test = np.loadtxt(
        os.path.join(folder_path, "x_test.txt"),
        dtype=int
    )

    y_test = np.loadtxt(
        os.path.join(folder_path, "y_test.txt"),
        dtype=int
    )

    # --------------------------------------------------------
    # UPDATE HARDWARE PARAMETERS
    # --------------------------------------------------------

    config.NUM_FEATURES = x_train.shape[1]

    config.CLAUSE_WIDTH = (
        config.NUM_FEATURES * 2
    )

    config.VIVADO_BUS_WIDTH = (
        config.CLAUSE_WIDTH
    )

    config.NUM_CLASSES = len(
        np.unique(y_train)
    )

    print("\n=======================================================")
    print("Dataset Loaded Successfully")
    print("=======================================================")
    print(f"Features : {config.NUM_FEATURES}")
    print(f"Classes  : {config.NUM_CLASSES}")
    print(f"Train    : {len(x_train)}")
    print(f"Test     : {len(x_test)}")
    print("=======================================================\n")

    return {
        "x_train": x_train,
        "y_train": y_train,
        "x_test": x_test,
        "y_test": y_test
    }
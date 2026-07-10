def get_prediction(
        tm,
        sample
):

    prediction = tm.predict(
        sample.reshape(1, -1)
    )[0]

    return int(prediction)
def average_positive(nums):
    positives = [x for x in nums if x > 0]
    total = 0
    for x in positives:
        total += x
    return total / len(positives)


def _main():
    import sys
    import traceback

    try:
        average_positive([-1, -2, -3])
    except Exception:
        tb = traceback.extract_tb(sys.exc_info()[2])
        for frame in tb:
            if frame.name == "average_positive":
                print(frame.lineno)
                return
        raise
    raise SystemExit("expected an exception, none raised")


if __name__ == "__main__":
    _main()

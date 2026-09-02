def sum_first_n(nums, n):
    total = 0
    for i in range(n):
        total += nums[i + 1]
    return total


def _main():
    import sys
    import traceback

    try:
        sum_first_n([10, 20, 30], 3)
    except Exception:
        tb = traceback.extract_tb(sys.exc_info()[2])
        for frame in tb:
            if frame.name == "sum_first_n":
                print(frame.lineno)
                return
        raise
    raise SystemExit("expected an exception, none raised")


if __name__ == "__main__":
    _main()

def f(nums):
    # nums: a list of integers
    total = 0
    count = 0
    n = len(nums)
    for i in range(1, n - 1):
        value = nums[i]
        total += value
        count += 1
    if count == 0:
        return 0
    return total


if __name__ == "__main__":
    print(f([10, 20, 30, 40, 50]))

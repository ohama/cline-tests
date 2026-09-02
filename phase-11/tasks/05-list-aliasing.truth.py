def f(items):
    original = items
    modified = items
    threshold = 2
    kept = []
    for x in modified:
        if x > threshold:
            kept.append(x)
    modified.append(100)
    modified.append(200)
    return len(original)


if __name__ == "__main__":
    print(f([1, 2, 3, 4, 5]))

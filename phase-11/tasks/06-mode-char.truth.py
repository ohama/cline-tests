def f(text):
    counts = {}
    for ch in text:
        if ch.isalpha():
            key = ch.lower()
            counts[key] = counts.get(key, 0) + 1
    max_count = 0
    max_char = ""
    for key in sorted(counts):
        if counts[key] > max_count:
            max_count = counts[key]
            max_char = key
    return max_char


if __name__ == "__main__":
    print(f("banana"))

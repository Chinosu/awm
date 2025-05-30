func info(_ line: String) {
    print("\u{1b}[0;36m" + "(info)" + "\u{1b}[0m" + " " + line)
}

func debu(_ line: String) {
    print("\u{1b}[0;33m" + "(debu)" + "\u{1b}[0m" + " " + line)
}

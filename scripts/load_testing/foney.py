# thanks to https://gist.github.com/ifnull/a32fcc90cd60f6e85b57


def area_codes(count_start=200, count=1000):
    """
    NPA (Area Code) Rules:
    http://www.nanpa.com/area_codes/index.html
    * Starts with [2-9].
    * Does not end in 11 (N11).
    * Does not end in 9* (N9X).
    * Does not start with 37 (37X).
    * Does not start with 96 (96X).
    * Does not contain ERC (Easily Recognizable
      Codes) AKA last two digits aren't the same.
    """
    npa = []

    for x in range(count_start, count):
        s = str(x)
        # N11
        if s[1:] == '11':
            continue
        # N9X
        if s[1:-1] == '9':
            continue
        # 37X/96X
        if s[:2] == '37' or s[:2] == '96':
            continue
        # ERC
        if s[1:2] == s[2:3]:
            continue
        npa.append(x)

    return npa


def prefixes(count_start=200, count=1000):
    """
    CO (Prefix) Rules:
    * Starts with [2-9].
    * Does not end with 11 (N11).
    """
    co = []

    for x in range(count_start, count):
        s = str(x)
        # N11
        if s[1:] == '11':
            continue
        co.append(x)

    return co


def phone_numbers(npa=206, count_start=1, count=1000):
    pns = []

    for co in prefixes():
        for sub in range(count_start, count):
            sub = "%04d" % sub
            pn = '{0}{1}{2}'.format(npa, co, sub)
            pns.append(pn)

    return pns

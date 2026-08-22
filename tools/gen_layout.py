#!/usr/bin/env python
"""Generate Init_Pos_X_Lo / Init_Pos_Y tables for 37Balls from an ASCII grid.

The startup image is spelled out by the balls themselves, two digits side by
side.  Each digit is a 6-column x 6-row cell grid; a '#' places a ball, any
other character leaves the cell empty.

Balls are 32px but the cell steps are 18 (X) and 13 (Y), so neighbours overlap
heavily - that overlap is what makes the strokes read as solid rather than as a
row of separate circles.

    X, left digit  (col 0-5)  = col * 18
    X, right digit (col 6-11) = (col + 2) * 18
    Y              (row r)    = r * 13

The two-column gap between the digits is why the right digit is offset by 2.

Those give relative spacing only.  The whole image is then slid so its
top-left ball sits at (X_ORIGIN, Y_ORIGIN) - both 0, so the image is flush
into the top-left corner of the screen rather than centred.  The slide is
computed from the smallest X and Y actually used, not from column 0 / row 0,
so the image stays flush however the ASCII is redrawn: leading empty columns
or rows in the grid do not push it away from the corner.

Balls are emitted ROW-MAJOR (all of row 0, then row 1, ...).  This matters:
NTSC draws only the first MAX_SPRITES_NTSC balls, so row-major degrades to the
top of the image instead of something scattered.

Usage:
    python tools/gen_layout.py Assets/layout48.txt --count 48           # print
    python tools/gen_layout.py Assets/layout48.txt --count 48 --write   # splice
"""

import argparse
import re
import sys

X_STEP = 18
Y_STEP = 13
COLS = 12
DIGIT_COLS = 6
BALL = 32
SCREEN_W = 320
SCREEN_H = 240
X_ORIGIN = 0            # Left edge of the image - 0 puts it on the border
Y_ORIGIN = 0            # Top edge  of the image - 0 puts it on the border
X_CLAMP = 288           # Set_Positions clamps X here
Y_CLAMP = 200           # ...and Y at Y_POS_MAX, derived from CLEAR_H
SOURCE = "demo.asm"     # --write target when none is named


def x_for(col):
    """Cell column -> X offset.  The right digit sits two columns further on."""
    return col * X_STEP if col < DIGIT_COLS else (col + 2) * X_STEP


def y_for(row):
    return row * Y_STEP


def read_grid(path):
    """Parse the grid, ignoring blank lines and '; ...' comment lines."""
    rows = []
    for raw in open(path, encoding="latin-1"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith(";"):
            continue
        cells = [c == "#" for c in line[:COLS].ljust(COLS)]
        rows.append(cells)
    if not rows:
        sys.exit("error: no grid rows found in %s" % path)
    return rows


def emit(name, values, comment):
    out = ["%s" % name]
    for i in range(0, len(values), 16):
        chunk = values[i:i + 16]
        out.append("\tdta " + ",".join("$%02X" % v for v in chunk) +
                   "\t; Objs $%02X-$%02X" % (i, i + len(chunk) - 1))
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("grid")
    ap.add_argument("--count", type=int, required=True,
                    help="expected ball count (must equal MAX_SPRITES_PAL)")
    ap.add_argument("--write", metavar="ASM", nargs="?", const=SOURCE,
                    help="splice the tables into ASM (default %s) instead of "
                         "printing them" % SOURCE)
    args = ap.parse_args()

    rows = read_grid(args.grid)
    nrows = len(rows)
    xs, ys = [], []
    for r in range(nrows):
        for c in range(COLS):
            if rows[r][c]:
                xs.append(x_for(c))
                ys.append(y_for(r))

    # The whole point of this tool: a grid with the wrong number of '#' would
    # otherwise show up as a silent visual bug (missing balls, or balls left at
    # whatever the previous table held).
    if len(xs) != args.count:
        sys.exit("error: grid has %d balls, expected %d (edit %s)"
                 % (len(xs), args.count, args.grid))

    # Slide the image so its top-left ball lands on the origin.  Taken off the
    # smallest coordinate in use rather than off cell (0,0), so empty leading
    # columns or rows in the ASCII do not shift the image off the corner.
    dx, dy = X_ORIGIN - min(xs), Y_ORIGIN - min(ys)
    xs = [x + dx for x in xs]
    ys = [y + dy for y in ys]

    for v, what, limit in ((max(xs), "X", X_CLAMP), (max(ys), "Y", Y_CLAMP)):
        if v > limit:
            sys.exit("error: max %s is %d, past the %d clamp" % (what, v, limit))

    tables = emit("Init_Pos_X_Lo", xs, None) + "\n" + emit("Init_Pos_Y", ys, None)

    summary = ("%d balls in a %dx%d grid; X %d..%d, Y %d..%d; image %dx%d px "
               "at the top-left, %d px clear right and %d px below"
               % (len(xs), COLS, nrows, min(xs), max(xs), min(ys), max(ys),
                  max(xs) - min(xs) + BALL, max(ys) - min(ys) + BALL,
                  SCREEN_W - (max(xs) + BALL), SCREEN_H - (max(ys) + BALL)))

    if not args.write:
        print("; " + summary)
        print(tables)
        return

    replace_tables(args.write, tables)
    print("%s: %s" % (args.write, summary))


def replace_tables(path, tables):
    """Swap the two dta blocks in place, leaving the rest of the file alone."""
    src = open(path, encoding="latin-1", newline=None).read()
    block = re.compile(r"^Init_Pos_X_Lo\n(?:\tdta [^\n]*\n)+"
                       r"Init_Pos_Y\n(?:\tdta [^\n]*\n)+", re.M)
    if not block.search(src):
        sys.exit("error: could not find the Init_Pos_X_Lo/Init_Pos_Y tables in %s"
                 % path)
    src = block.sub(lambda _: tables + "\n", src, count=1)
    # The Atari sources are CRLF throughout; do not let Python quietly convert.
    open(path, "w", encoding="latin-1", newline="\r\n").write(src)


if __name__ == "__main__":
    main()

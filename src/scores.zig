const std = @import("std");

pub var scores = [_]u8{0} ** 2097152;

pub fn initScores() void {
    var a: u32 = 0;
    while (a < 8) : (a += 1) {
        var b: u32 = 0;
        while (b < 8) : (b += 1) {
            var c: u32 = 0;
            while (c < 8) : (c += 1) {
                var d: u32 = 0;
                while (d < 8) : (d += 1) {
                    var e: u32 = 0;
                    while (e < 8) : (e += 1) {
                        var f: u32 = 0;
                        while (f < 8) : (f += 1) {
                            var g: u32 = 0;
                            while (g < 8) : (g += 1) {
                                const index = a + 8 * b + 8 * 8 * c + 8 * 8 * 8 * d + 8 * 8 * 8 * 8 * e + 8 * 8 * 8 * 8 * 8 * f + 8 * 8 * 8 * 8 * 8 * 8 * g;
                                var score: u8 = 0;

                                if (a != 0 and b != 0 and c != 0 and a == g and b == f and c == e) {
                                    score += 7;
                                }
                                if (a != 0 and b != 0 and c != 0 and a == f and b == e and c == d) {
                                    score += 6;
                                }
                                if (a != 0 and b != 0 and a == e and b == d) {
                                    score += 5;
                                }
                                if (a != 0 and b != 0 and a == d and b == c) {
                                    score += 4;
                                }
                                if (a != 0 and a == c) {
                                    score += 3;
                                }
                                if (a != 0 and a == b) {
                                    score += 2;
                                }

                                if (b != 0 and c != 0 and d != 0 and b == g and c == f and d == e) {
                                    score += 6;
                                }
                                if (b != 0 and c != 0 and b == f and c == e) {
                                    score += 5;
                                }
                                if (b != 0 and c != 0 and b == e and c == d) {
                                    score += 4;
                                }
                                if (b != 0 and b == d) {
                                    score += 3;
                                }
                                if (b != 0 and b == c) {
                                    score += 2;
                                }

                                if (c != 0 and d != 0 and c == g and d == f) {
                                    score += 5;
                                }
                                if (c != 0 and d != 0 and c == f and d == e) {
                                    score += 4;
                                }
                                if (c != 0 and c == e) {
                                    score += 3;
                                }
                                if (c != 0 and c == d) {
                                    score += 2;
                                }

                                if (d != 0 and e != 0 and d == g and e == f) {
                                    score += 4;
                                }
                                if (d != 0 and d == f) {
                                    score += 3;
                                }
                                if (d != 0 and d == e) {
                                    score += 2;
                                }

                                if (e != 0 and e == g) {
                                    score += 3;
                                }
                                if (e != 0 and e == f) {
                                    score += 2;
                                }

                                if (f != 0 and f == g) {
                                    score += 2;
                                }

                                scores[index] = score;
                            }
                        }
                    }
                }
            }
        }
    }
}

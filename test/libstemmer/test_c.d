// Copyright Nickolay Bukreyev 2025.
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file License_1_0.txt or copy at https://www.boost.org/LICENSE_1_0.txt)

module libstemmer.test_c;

import libstemmer.c;

nothrow @system @nogc:

pure @safe unittest {
    const a = sb_stemmer_list();
    assert(a !is null);
    assert(*a !is null);
}

unittest {
    auto st = sb_stemmer_new("ru", null);
    assert(st !is null);
    scope(exit) sb_stemmer_delete(st);
    enum butyavka = "бутявка";
    const result = sb_stemmer_stem(st, cast(immutable(ubyte)*)butyavka, cast(int)butyavka.length);
    assert(result !is null);
    assert(result[0 .. sb_stemmer_length(st)] == "бутявк");
}

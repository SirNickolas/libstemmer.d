// Copyright Nickolay Bukreyev 2025.
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file License_1_0.txt or copy at https://www.boost.org/LICENSE_1_0.txt)

import libstemmer;
static import libstemmer.test_with_druntime;

nothrow @safe @nogc:

pure unittest {
    import std.algorithm.searching: canFind;

    assert(SnowballStemmer.algorithms.canFind!(a => a == "english\0"));
}

pure unittest {
    SnowballStemmer st;
    assert(st.reset("english\0"));
    assert(st.reset("spanish\0",  SnowballStemmer.Encoding.iso8859_1));
    assert(st.reset("romanian\0", SnowballStemmer.Encoding.iso8859_2));
    assert(st.reset("russian\0",  SnowballStemmer.Encoding.koi8r));
    static assert(!__traits(compiles, { st.reset("english\0"); }) || __VERSION__ < 2_100);
}

pure unittest {
    SnowballStemmer st;
    assert(st.reset("en\0"));
    st.stemUtf8!((s) { assert(s == "cat"); })("cats");
    assert(st.stemUtf8!(s => "dog")("dogs") == "dog");
    static assert(!__traits(compiles, st.stemUtf8!(s => s)("dogs")));
    static assert(!__traits(compiles, st.stemUtf8!((s) @trusted => s)("dogs")));
    static assert(!__traits(compiles, st.stemUtf8!((s) @system => 1)("unsafe")));

    st.stemUtf8!((s) {
        assert(st.reset("ru\0"));
        assert(s == "transmogrifi");
    })("transmogrify");
    assert(!st.reset("abracadabra\0"));
    assert(!st.reset("english\0", cast(SnowballStemmer.Encoding)"abracadabra\0"));
    st.stemUtf8!((s) { assert(s == "получ"); })("получилось");
    destroy(st); // Safe against double free.
}

unittest {
    SnowballStemmer st;
    assert(st.reset("en\0"));
    st.stemUtf8!((s) {
        assert(s == "impur");
        static int n;
        n++;
    })("impurity");
}

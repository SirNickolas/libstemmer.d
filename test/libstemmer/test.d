import libstemmer;
static import libstemmer.test_with_druntime;

nothrow @safe @nogc:

pure unittest {
    import std.algorithm.searching: canFind;

    assert(SnowballStemmer.algorithms.canFind!(a => a == "english\0"));
}

pure unittest {
    SnowballStemmer.createAssumeOk("english\0");
    SnowballStemmer.createAssumeOk("spanish\0",  SnowballStemmer.Encoding.iso8859_1);
    SnowballStemmer.createAssumeOk("romanian\0", SnowballStemmer.Encoding.iso8859_2);
    SnowballStemmer.createAssumeOk("russian\0",  SnowballStemmer.Encoding.koi8r);
}

pure unittest {
    auto st = SnowballStemmer.createAssumeOk("en\0");
    st.stemUtf8!((s) { assert(s == "cat"); })("cats");
    assert(st.stemUtf8!(s => "dog")("dogs") == "dog");
    static assert(!__traits(compiles, st.stemUtf8!(s => s)("dogs")));
    static assert(!__traits(compiles, st.stemUtf8!((s) @trusted => s)("dogs")));
    static assert(!__traits(compiles, st.stemUtf8!((s) @system => 1)("unsafe")));

    st.stemUtf8!((s) {
        st = SnowballStemmer.createAssumeOk("ru\0");
        assert(s == "transmogrifi");
    })("transmogrify");
    st.stemUtf8!((s) { assert(s == "получ"); })("получилось");
    destroy(st); // Safe against double free.
}

unittest {
    auto st = SnowballStemmer.createAssumeOk("en\0");
    st.stemUtf8!((s) {
        assert(s == "impur");
        static int n;
        n++;
    })("impurity");
}

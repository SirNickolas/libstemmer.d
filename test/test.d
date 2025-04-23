import libstemmer;

@safe:

nothrow pure @nogc unittest {
    import std.algorithm.searching: canFind;

    assert(SnowballStemmer.algorithms.canFind("english\0"));
}

pure unittest {
    SnowballStemmer("english\0");
    SnowballStemmer("spanish\0",  SnowballStemmer.Encoding.iso8859_1);
    SnowballStemmer("romanian\0", SnowballStemmer.Encoding.iso8859_2);
    SnowballStemmer("russian\0",  SnowballStemmer.Encoding.koi8r);
}

pure @system unittest {
    import core.exception: AssertError;
    import std.exception: assertThrown;

    assertThrown!AssertError(SnowballStemmer("english"));
    assertThrown!AssertError(SnowballStemmer("english\0", cast(SnowballStemmer.Encoding)"UTF-8"));
}

pure unittest {
    import std.exception: assertThrown;

    assertThrown!SnowballStemmerException(SnowballStemmer("abracadabra\0"));
    assertThrown!SnowballStemmerException(
        SnowballStemmer("english\0", cast(SnowballStemmer.Encoding)"abracadabra\0")
    );
}

pure unittest {
    scope st = SnowballStemmer("english\0");
    assert(st.stemUtf8("superlative") == "superl");
    destroy(st); // Safe against double free.
}

pure unittest {
    scope st = SnowballStemmer("russian\0", SnowballStemmer.Encoding.koi8r);
    enum s = x"C8CFCDD1CBCFD7 D9CDC9"; // хомяковыми
    assert(st.stem(s) == s[0 .. 7]);
}

pure unittest {
    import std.algorithm.comparison: equal;
    import std.algorithm.iteration: filter, map, splitter;
    import std.uni: isAlpha;

    scope st = SnowballStemmer("ru\0");
    auto stems = q"EOF
Варкалось. Хливкие шорьки
Пырялись по наве,
И хрюкотали зелюки,
Как мюмзики в мове.
О бойся Бармаглота, сын!
Он так свирлеп и дик,
А в глyще рымит исполин —
Злопастный Брандашмыг.
EOF".splitter!(c => !c.isAlpha)
    .filter!q{a.length}
    .map!(word => st.stemUtf8(word));
    assert(stems.equal([
        "Варка", "Хливк", "шорьк", "Пыря", "по", "нав",
        "И", "хрюкота", "зелюк", "Как", "мюмзик", "в", "мов",
        "О", "бо", "Бармаглот", "сын", "Он", "так", "свирлеп", "и", "дик",
        "А", "в", "глyще", "рым", "исполин", "Злопастн", "Брандашмыг",
    ]));
}

pure unittest {
    auto st = SnowballStemmer("en\0");
    st.stemUtf8!((s) { assert(s == "cat"); })("cats");
    assert(st.stemUtf8!(s => s.dup)("dogs") == "dog");
    static assert(!__traits(compiles, st.stemUtf8!(s => s)("dogs")));

    st.stemUtf8!((s) {
        st = SnowballStemmer("ru\0");
        assert(s == "transmogrifi");
    })("transmogrify");
    assert(st.stemUtf8("получилось") == "получ");
}

pure unittest {
    assert(new SnowballStemmer("en\0").stemUtf8("indirection") == "indirect");
}

pure @system unittest {
    import core.exception: AssertError;
    import std.exception: assertThrown;

    SnowballStemmer st;
    assertThrown!AssertError(st.stemUtf8("uninitialized"));

    st = SnowballStemmer("en\0");
    assertThrown!AssertError(st.stemUtf8!(_ => st.stemUtf8("nested"))("outer"));

    auto a = new SnowballStemmer("en\0");
    auto b = a;
    a.stemUtf8!((s) @trusted {
        assert(s == "alias");
        assertThrown!AssertError(b.stemUtf8!(_ => 0)("nested"));
    })("aliasing");
}

unittest {
    auto st = SnowballStemmer("en\0");
    st.stemUtf8!((s) {
        assert(s == "impur");
        static int n;
        n++;
    })("impurity");
}

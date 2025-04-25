// Copyright Nickolay Bukreyev 2025.
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file License_1_0.txt or copy at https://www.boost.org/LICENSE_1_0.txt)

module libstemmer;

import libstemmer.c;

private @safe:

static if (__VERSION__ >= 2_100)
    import core.attribute: mustuse;
else
    enum mustuse;

immutable(char*)[ ] _getAlgorithmPtrs() nothrow pure @system @nogc {
    auto result = sb_stemmer_list();
    size_t n;
    for (auto p = result; *p !is null; p++)
        n++;
    return result[0 .. n];
}

immutable(string)[ ] _toStrings(immutable(char*)[ ] a) nothrow @system @nogc {
    import core.exception: onOutOfMemoryError;
    import core.stdc.stdlib: malloc;
    import core.stdc.string: strlen;

    auto result = cast(string*)malloc(a.length * string.sizeof);
    if (result is null)
        onOutOfMemoryError();
    foreach (i, p; a)
        result[i] = p[0 .. strlen(p) + 1];
    return cast(immutable)result[0 .. a.length];
}

__gshared _getAlgorithms = &_initAlgorithms;

immutable(string)[ ] _initAlgorithms() nothrow @system @nogc {
    __gshared immutable(string)[ ] algos;
    // In presence of data races, it is important to assign `algos` prior to `_getAlgorithms`.
    scope(exit) _getAlgorithms = () => algos;
    return (algos = _getAlgorithmPtrs()._toStrings());
}

sb_stemmer* _createStemmer(scope const(char)* algorithm, scope const(char)* encoding)
nothrow @system @nogc {
    import core.stdc.errno: errno;

    const e = errno;
    scope(exit) errno = e;
    return sb_stemmer_new(algorithm, encoding);
}

sb_stemmer* _createStemmer(scope const(char)[ ] algorithm, scope const(char)[ ] encoding)
nothrow pure @trusted @nogc
in {
    assert(!algorithm[$ - 1], "`algorithm` must be zero-terminated");
    assert(encoding is null || !encoding[$ - 1], "`encoding` must be zero-terminated");
}
do {
    alias F = sb_stemmer* function(scope const(char)*, scope const(char)*) nothrow pure @nogc;
    return (cast(F)&_createStemmer)(algorithm.ptr, encoding.ptr);
}

@mustuse struct _Bool {
    bool ok;

    alias ok this;
}

///
version (D_BetterC) { }
else
public class SnowballStemmerException: Exception {
    import std.exception: basicExceptionCtors;

    mixin basicExceptionCtors; ///
}

/++
    Encapsulates a stemmer, providing safe interface to it.

    This struct is non-copyable. If this makes you unhappy, allocate it with `new`
    or `safeRefCounted`.
+/
public struct SnowballStemmer {
pure:
    ///
    enum Encoding: string {
        utf8 = null, ///
        iso8859_1 = "ISO_8859_1\0", /// ditto
        iso8859_2 = "ISO_8859_2\0", /// ditto
        koi8r = "KOI8_R\0", /// ditto
    }

    private sb_stemmer* _h;

    /++
        Get a list of supported stemming _algorithms (i.e., languages).

        Only the canonical name of each algorithm is returned: `"english\0"` is there, but `"en\0"`
        is not. See [modules.txt] to get an impression of what this list may look like.

        [modules.txt]: https://github.com/snowballstem/snowball/blob/master/libstemmer/modules.txt
    +/
    static immutable(string)[ ] algorithms() nothrow @trusted @nogc {
        return (cast(immutable(string)[ ] function() nothrow pure @nogc)() => _getAlgorithms())();
    }

    /++
        Construct a stemmer with the specified _algorithm and input _encoding.

        `algorithm` and `encoding` are case-sensitive and must be zero-terminated (e.g., you have
        to pass `"en\0"`, not `"en"`); that is asserted.

        This constructor is unavailable in *betterC* mode.

        Throws: `SnowballStemmerException` on an unknown _algorithm or _encoding or an unsupported
        combination of those.
    +/
    version (D_BetterC) { }
    else
    this(scope const(char)[ ] algorithm, scope Encoding encoding = Encoding.utf8) scope {
        if (auto h = _createStemmer(algorithm, encoding))
            _h = h;
        else
            throw new SnowballStemmerException("Unsupported algorithm or encoding");
    }

    @disable this(this);

    ~this() scope nothrow @trusted @nogc {
        sb_stemmer_delete(_h);
    }

    /++
        Try to change the _algorithm and _encoding used by this stemmer.

        `algorithm` and `encoding` are case-sensitive and must be zero-terminated (e.g., you have
        to pass `"en\0"`, not `"en"`); that is asserted.

        The return type of this method implicitly converts to `bool`. If `algorithm` or `encoding`
        are unknown or their combination is unsupported, then `false` is returned and no changes
        are made.
    +/
    _Bool reset(scope const(char)[ ] algorithm, scope Encoding encoding = Encoding.utf8)
    scope nothrow @trusted @nogc {
        if (auto h = _createStemmer(algorithm, encoding)) {
            sb_stemmer_delete(_h);
            _h = h;
            return _Bool(true);
        }
        return _Bool.init;
    }

    ///
    bool isNull() scope const nothrow @nogc { return _h is null; }

    /++
        Acquire ownership over a low-level stemmer.

        It will be deleted automatically, hence `@system`.
    +/
    this(sb_stemmer* handle) scope nothrow @system @nogc {
        _h = handle;
    }

    /++
        Get the low-level stemmer.

        Manipulating it directly may interfere with `SnowballStemmer`, hence `@system`.
    +/
    inout(sb_stemmer)* handle() scope inout nothrow @system @nogc {
        auto h = _h;
        return h;
    }

    /++
        Extract the low-level stemmer.

        From now on, you are responsible for deleting it.
    +/
    sb_stemmer* release() scope nothrow @trusted @nogc {
        auto h = _h;
        _h = null;
        return h;
    }

    private void _restore(scope sb_stemmer* backup) scope nothrow @trusted @nogc {
        if (_h is null)
            _h = backup; // `scope sb_stemmer*` is a lie.
        else
            sb_stemmer_delete(backup);
    }
}

const(ubyte)[ ] _exec(return sb_stemmer* h, scope const(ubyte)[ ] word) nothrow pure @trusted @nogc
in {
    assert(h !is null, "`SnowballStemmer` has not been initialized");
    assert(word.length <= int.max);
}
do {
    import core.exception: onOutOfMemoryError;

    alias F = extern(C) const(ubyte)* function(sb_stemmer*, const(ubyte)*, int) nothrow pure @nogc;
    const p = (cast(F)&sb_stemmer_stem)(h, word.ptr, cast(int)word.length);
    if (p is null)
        onOutOfMemoryError();
    return p[0 .. sb_stemmer_length(h)];
}

public
version (D_Ddoc) {
    /++
        Determine the _stem of the given _word.

        The _stem is passed to `callback`, which it must not escape. (If you compile with
        `-dip1000`, the compiler will enforce that.) Also, `callback` has to be `@safe`
        or `@trusted`. Whatever it returns will be passed back to the caller.

        During `callback` invocation, you cannot _stem another _word with the same stemmer. (Doing
        so will result in assertion failure.)

        `stemUtf8` does not actually require the stemmer to be created with `Encoding.utf8`; it is
        merely a convenience function that inserts `char[ ] <-> ubyte[ ]` casts. It can be used
        interchangeably with `stem`; but there is a convention in the D community that `char[ ]`
        contains UTF-8 and `ubyte[ ]` holds arbitrary binary data.

        Note these are not member functions (to avoid deprecations about dual context). Thanks
        to UFCS, most of the time there is no difference.
    +/
    auto stemUtf8(alias callback)(ref scope SnowballStemmer st, scope const(char)[ ] word) @safe {
        return callback(word);
    }

    /// ditto
    auto stem(alias callback)(ref scope SnowballStemmer st, scope const(ubyte)[ ] word) @safe {
        return callback(word);
    }

    ///
    pure unittest {
        auto st = SnowballStemmer("en\0");
        st.stemUtf8!((stem) {
            assert(stem == "minifi");
        })("minify");
    }
} else {
    private auto _stem(C, alias callback)(ref scope SnowballStemmer st, scope const(C)[ ] word) {
        auto backup = st._h;
        scope stem = cast(const(C)[ ])backup._exec(cast(const(ubyte)[ ])word);
        // We temporarily steal `_h` so that `callback` cannot destroy it and invalidate `stem`.
        st._h = null;
        scope(exit) st._restore(backup);
        return callback(stem);
    }

    alias stemUtf8(alias callback) = _stem!(char, callback);
    alias stem(alias callback) = _stem!(ubyte, callback);
}

version (D_BetterC) { }
else {
public pure:
    /++
        Determine the _stem of the given _word; allocate from the GC heap.

        Only provided for convenience. When possible, you are encouraged to use the [other
        overload](#stemUtf8), which does not allocate; please refer to it for detailed
        documentation.
    +/
    pragma(inline, true)
    string stemUtf8(ref scope SnowballStemmer st, scope const(char)[ ] word) nothrow {
        return cast(string)st._h._exec(cast(const(ubyte)[ ])word).idup;
    }

    /// ditto
    pragma(inline, true)
    immutable(ubyte)[ ] stem(ref scope SnowballStemmer st, scope const(ubyte)[ ] word) nothrow {
        return st._h._exec(word).idup;
    }

    ///
    unittest {
        auto st = SnowballStemmer("en\0");
        assert(st.stemUtf8("minify") == "minifi");
    }
}

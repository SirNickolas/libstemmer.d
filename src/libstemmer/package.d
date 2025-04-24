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

///
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

    ///
    static immutable(string)[ ] algorithms() nothrow @trusted @nogc {
        return (cast(immutable(string)[ ] function() nothrow pure @nogc)() => _getAlgorithms())();
    }

    ///
    version (D_BetterC) { }
    else
    this(scope const(char)[ ] algorithm, scope Encoding encoding = Encoding.utf8) scope {
        if (auto h = _createStemmer(algorithm, encoding))
            _h = h;
        else
            throw new SnowballStemmerException("Unsupported algorithm or encoding");
    }

    ///
    this(sb_stemmer* handle) scope nothrow @system @nogc {
        _h = handle;
    }

    @disable this(this);

    ~this() scope nothrow @trusted @nogc {
        sb_stemmer_delete(_h);
    }

    ///
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
    inout(sb_stemmer)* handle() scope inout nothrow @system @nogc {
        auto h = _h;
        return h;
    }

    ///
    sb_stemmer* release() scope nothrow @trusted @nogc {
        scope(exit) _h = null;
        auto h = _h;
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

auto _stem(alias callback, C)(ref scope SnowballStemmer st, scope const(C)[ ] word) {
    auto backup = st._h;
    scope stem = cast(const(C)[ ])backup._exec(cast(const(ubyte)[ ])word);
    st._h = null;
    scope(exit) st._restore(backup);
    return callback(stem);
}

public pragma(inline, true) {
    version (D_BetterC) { }
    else nothrow pure {
        ///
        string stemUtf8(ref scope SnowballStemmer st, scope const(char)[ ] word) {
            return cast(string)st._h._exec(cast(const(ubyte)[ ])word).idup;
        }

        /// ditto
        immutable(ubyte)[ ] stem(ref scope SnowballStemmer st, scope const(ubyte)[ ] word) {
            return st._h._exec(word).idup;
        }
    }

    ///
    auto stemUtf8(alias callback)(ref scope SnowballStemmer st, scope const(char)[ ] word) {
        return _stem!callback(st, word);
    }

    /// ditto
    auto stem(alias callback)(ref scope SnowballStemmer st, scope const(ubyte)[ ] word) {
        return _stem!callback(st, word);
    }
}

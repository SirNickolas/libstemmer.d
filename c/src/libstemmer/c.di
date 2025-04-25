// Copyright Nickolay Bukreyev 2025.
// Distributed under the Boost Software License, Version 1.0.
// (See accompanying file License_1_0.txt or copy at https://www.boost.org/LICENSE_1_0.txt)

/// See_Also: https://github.com/snowballstem/snowball/blob/master/include/libstemmer.h
module libstemmer.c;

extern(C) nothrow @system @nogc: // Not pure since they may modify `errno`.

struct sb_stemmer; ///

// Wrongly declared as `const char**` in C - should be `const char* const*` instead.
immutable(char*)* sb_stemmer_list() pure @safe; ///
sb_stemmer* sb_stemmer_new(scope const(char)* algorithm, scope const(char)* charenc); ///
void sb_stemmer_delete(sb_stemmer*) pure; ///
const(ubyte)* sb_stemmer_stem(sb_stemmer*, scope const(ubyte)* word, int size); ///
int sb_stemmer_length(sb_stemmer*) pure; ///

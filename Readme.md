# `libstemmer` for D

## Synopsis

```d
import std.algorithm, std.array, std.uni;
import libstemmer;

auto stemmer = SnowballStemmer("ru\0");
string s = q"EOF
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
    .map!(word => stemmer.stemUtf8(word)) // <==
    .join(' ');
assert(s == "Варка Хливк шорьк Пыря по нав И хрюкота зелюк Как мюмзик в мов" ~
    " О бо Бармаглот сын Он так свирлеп и дик А в глyще рым исполин Злопастн Брандашмыг");
```

This is D bindings to `libstemmer`, a C library of [Snowball] stemming algorithms.

> Snowball provides access to efficient algorithms for calculating a
> “stemmed” form of a word.  This is a form with most of the common
> morphological endings removed; hopefully representing a common
> linguistic base form.  This is most useful in building search engines
> and information-retrieval software; for example, a search with stemming
> enabled should be able to find a document containing “cycling” given the
> query “cycles”.
>
> Snowball provides algorithms for several (mainly European) languages.
> It also provides access to the classic Porter stemming algorithm for
> English: although this has been superseded by an improved algorithm, the
> original algorithm may be of interest to information-retrieval
> researchers wishing to reproduce results of earlier experiments.

[Snowball]: https://snowballstem.org


## Installation

Since `libstemmer-d` only provides bindings, you also need to install the original C `libstemmer`
library. For example, on Ubuntu:

```sh
sudo apt install libstemmer-dev
```

By default, this package will attempt to dynamically link to the C `libstemmer` library installed
in a standard place on your system (and hopefully work out of the box). If that is undesirable, add
the following line to your `dub.sdl`, then pass arguments for the linker as needed:

```c
subConfiguration "libstemmer-d:c" "without-library"
```


## Usage

[API docs](https://sirnickolas.github.io/libstemmer.d/package)

In addition to stemming, you may want to filter out stop words. `libstemmer` deals nothing
to them, as the synopsis shows, so their handling is up to you. Snowball project, for example,
provides stop-word lists for [some of the languages](https://snowballstem.org/algorithms/).


## See Also

* [gedaiu/stemmer]—D implementation of the classic Porter algorithm; English only.
* [PyMorphy2]—A morphological analyzer in Python (and partially C); Russian and Ukrainian only.
* [Yandex MyStem]—Rocket science; Russian only; free but not open source.

[gedaiu/stemmer]: https://github.com/gedaiu/stemmer
[PyMorphy2]: https://github.com/pymorphy2/pymorphy2
[Yandex MyStem]: https://tech.yandex.ru/mystem/

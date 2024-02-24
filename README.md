## :lizard: :card_index_dividers: **zig indexlist**

[![CI][ci-shd]][ci-url]
[![CC][cc-shd]][cc-url]
[![LC][lc-shd]][lc-url]

### Zig port of the [doubly-linked list backed by an array](https://github.com/steveklabnik/indexlist) created by [Steve Klabnik](https://github.com/steveklabnik).

### :rocket: Usage

1. Add `indexlist` as a dependency in your `build.zig.zon`.

    <details>

    <summary><code>build.zig.zon</code> example</summary>

    ```zig
    .{
        .name = "<name_of_your_package>",
        .version = "<version_of_your_package>",
        .dependencies = .{
            .indexlist = .{
                .url = "https://github.com/tensorush/zig-indexlist/archive/<git_tag_or_commit_hash>.tar.gz",
                .hash = "<package_hash>",
            },
        },
    }
    ```

    Set `<package_hash>` to `12200000000000000000000000000000000000000000000000000000000000000000`, and Zig will provide the correct found value in an error message.

    </details>

2. Add `indexlist` as a module in your `build.zig`.

    <details>

    <summary><code>build.zig</code> example</summary>

    ```zig
    const indexlist = b.dependency("indexlist", .{});
    exe.addModule("indexlist", indexlist.module("indexlist"));
    ```

    </details>

<!-- MARKDOWN LINKS -->

[ci-shd]: https://img.shields.io/github/actions/workflow/status/tensorush/zig-indexlist/ci.yaml?branch=main&style=for-the-badge&logo=github&label=CI&labelColor=black
[ci-url]: https://github.com/tensorush/zig-indexlist/blob/main/.github/workflows/ci.yaml
[cc-shd]: https://img.shields.io/codecov/c/github/tensorush/zig-indexlist?style=for-the-badge&labelColor=black
[cc-url]: https://app.codecov.io/gh/tensorush/zig-indexlist
[lc-shd]: https://img.shields.io/github/license/tensorush/zig-indexlist.svg?style=for-the-badge&labelColor=black
[lc-url]: https://github.com/tensorush/zig-indexlist/blob/main/LICENSE.md

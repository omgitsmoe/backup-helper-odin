package checksum_helper

import "core:testing"

@(test)
matcher :: proc(t: ^testing.T) {
    builder := Matcher_Builder{}

    testing.expect(t, matcher_builder_allow(&builder, "foo/**/*.zig") == nil);
    testing.expect(t, matcher_builder_allow(&builder, "**/*.txt") == nil);

    testing.expect(t, matcher_builder_block(&builder, "bar/**/*") == nil);
    testing.expect(t, matcher_builder_block(&builder, "**/*.go") == nil);
    testing.expect(t, matcher_builder_block(&builder, "foo/bar/*.zig") == nil);

    matcher := matcher_builder_build(&builder)
    defer matcher_destroy(&matcher)

    testing.expect(t, matcher_is_blocked(matcher, "bar/foo/xer.zig"));
    testing.expect(t, matcher_is_blocked(matcher, "bar/xer.bin"));
    testing.expect(t, matcher_is_blocked(matcher, "foo.go"));
    testing.expect(t, matcher_is_blocked(matcher, "xer/foo.go"));
    testing.expect(t, matcher_is_blocked(matcher, "foo/bar/abc.zig"));
    testing.expect(t, !matcher_is_match(matcher, "foo/bar/abc.zig"));

    testing.expect(t, matcher_is_match(matcher, "foo/xer/abc.zig"));
    testing.expect(t, matcher_is_match(matcher, "xer/file.txt"));
}

@(test)
matcher_trailing_slash_patterns_match :: proc(t: ^testing.T) {
    {
        builder := Matcher_Builder{}

        testing.expect(t, matcher_builder_block(&builder, "foo/bar/") == nil);
        testing.expect(t, matcher_builder_allow(&builder, "**/*.txt") == nil);

        matcher := matcher_builder_build(&builder)
        defer matcher_destroy(&matcher)

        // matcher_is_blocked directory path
        testing.expect(t, matcher_is_blocked(matcher, "foo/bar"));
        testing.expect(t, matcher_is_blocked(matcher, "foo/bar/"));

        // matcher_is_match still works for files at root
        testing.expect(t, matcher_is_match(matcher, "a.txt"));
        testing.expect(t, !matcher_is_match(matcher, "other.bin"));
    }

    {
        // Same result without trailing slash
        builder := Matcher_Builder{}
        testing.expect(t, matcher_builder_block(&builder, "foo/bar") == nil);
        testing.expect(t, matcher_builder_allow(&builder, "**/*.txt") == nil);

        matcher := matcher_builder_build(&builder);
        defer matcher_destroy(&matcher)

        testing.expect(t, matcher_is_blocked(matcher, "foo/bar"));
        testing.expect(t, matcher_is_match(matcher, "a.txt"));
        testing.expect(t, !matcher_is_match(matcher, "other.bin"));
    }
}

@(test)
matcher_empty_match_all_block_nothing :: proc(t: ^testing.T) {
    builder := Matcher_Builder{}

    matcher := matcher_builder_build(&builder)
    defer matcher_destroy(&matcher)

    testing.expect(t, !matcher_is_blocked(matcher, "bar/foo/xer.zig"));
    testing.expect(t, !matcher_is_blocked(matcher, "bar/xer.bin"));
    testing.expect(t, !matcher_is_blocked(matcher, "foo.go"));
    testing.expect(t, !matcher_is_blocked(matcher, "xer/foo.go"));
    testing.expect(t, !matcher_is_blocked(matcher, "foo/bar/abc.zig"));

    testing.expect(t, matcher_is_match(matcher, "foo/bar/abc.zig"));
    testing.expect(t, matcher_is_match(matcher, "foo/xer/abc.zig"));
    testing.expect(t, matcher_is_match(matcher, "xer/file.txt"));
    testing.expect(t, matcher_is_match(matcher, "file.txt"));
}


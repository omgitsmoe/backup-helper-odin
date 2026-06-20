package glob

import "core:log"
import "core:testing"

@(test)
parse_test :: proc(t: ^testing.T) {
	S :: Node_Symbol

	expect_parse(t, pattern_from_string(""), {})
	expect_parse(t, pattern_from_string("/"), {S.Slash})
	expect_parse(t, pattern_from_string("foo/bar"), {"foo", S.Slash, "bar"})
	expect_parse(
		t,
		pattern_from_string("foo/*/*.bar"),
		{"foo", S.Slash, S.Any_Text, S.Slash, S.Any_Text, ".bar"},
	)
	expect_parse(
		t,
		pattern_from_string("foo/**/bar"),
		{"foo", S.Slash, S.Globstar, S.Slash, "bar"},
	)
	expect_parse(t, pattern_from_string("foo/?.bar"), {"foo", S.Slash, S.Any_Char, ".bar"})

	expect_parse(t, pattern_from_string("{foo,bar}"), {Node_Or{patterns = {{"foo"}, {"bar"}}}})
	expect_parse(
		t,
		pattern_from_string("{**/bin,bin}"),
		{Node_Or{patterns = {{S.Globstar, S.Slash, "bin"}, {"bin"}}}},
	)

	expect_parse(
		t,
		pattern_from_string("[ab0-9]"),
		{Node_Or{patterns = {{"a"}, {"b"}, {Node_Range{a = '0', b = '9'}}}}},
	)
	expect_parse(
		t,
		pattern_from_string("[0-9]"),
		{Node_Or{patterns = {{Node_Range{a = '0', b = '9'}}}}},
	)

	expect_parse(
		t,
		pattern_from_string("[!c]at"),
		{Node_Or{patterns = {{"c"}}, negate = true}, "at"},
	)
}

@(private)
expect_match :: proc(
	t: ^testing.T,
	pattern: string,
	expected: string,
	match_expeced: bool,
	loc := #caller_location,
) {
	matched, err := match(pattern, expected)
	testing.expect_value(t, err, nil, loc)
	testing.expect_value(t, matched, match_expeced, loc)
}

@(test)
match_test :: proc(t: ^testing.T) {
	expect_match(t, "/**/bin", "/foo/bar/bin", true)
	expect_match(t, "/**/bin", "/foo/bar/hellope", false)
	expect_match(t, "/**/bin", "//bin", true)
	expect_match(t, "/**/bin", "/bin", false)
	// TODO: fix
	expect_match(t, "**/bin", "/bin", true)
	expect_match(t, "*/bin", "/bin", true)
	expect_match(t, "*/bin", "bin", false)
	expect_match(t, "*/bin", "foo/bin", true)
	expect_match(t, "/*/bin", "/bin", false)
	expect_match(t, "/*/bin", "/foo/bin", true)
	expect_match(t, "/*/bin", "/foo/bar/bin", false)
	expect_match(t, "test/*/hellope", "test/bar/hellope", true)
	expect_match(t, "/**/test/*/hellope", "/foo/test/bar/hellope", true)
	expect_match(t, "?at", "cat", true)
	expect_match(t, "?at", "bat", true)
	expect_match(t, "?at", ".at", true)
	expect_match(t, "?at", ".ar", false)
	expect_match(t, "?at", "/at", false)

	expect_match(t, "{b,r}", "bat", true)
	expect_match(t, "{b,r}", "rat", true)
	expect_match(t, "{b,r}", "fat", false)

	expect_match(t, "**/foo/{**/bin,bin}", "bar/foo/test/2/bin", true)
	expect_match(t, "**/foo/{**/bin,?bar}", "bar/foo/8bar", true)

	expect_match(t, "[abc]", "a", true)
	expect_match(t, "[abc]", "b", true)
	expect_match(t, "[abc]", "c", true)
	expect_match(t, "[abc]", "d", false)
	expect_match(t, "[0-9]", "0", true)
	expect_match(t, "[0-9]", "9", true)
	expect_match(t, "[0-9]", "5", true)
	expect_match(t, "[0-9]", "a", false)
	expect_match(t, "[a-c]", "a", true)
	expect_match(t, "[a-c]", "b", true)
	expect_match(t, "[a-c]", "c", true)
	expect_match(t, "[a-c]", "d", false)


	expect_match(t, "[a-c]", "c", true)
	expect_match(t, "[<->]", "<", true)
	expect_match(t, "[<->]", "=", true)
	expect_match(t, "[<->]", ">", true)
	expect_match(t, "[<->]", "?", false)
	expect_match(t, "[ɐ-ʯ]", "ʧ", true)
	expect_match(t, "[ɐ-ʯ]", "ʰ", false)
	expect_match(t, "[٠-٩]", "٢", true)

	expect_match(t, "[!c]at", "at", true)
	expect_match(t, "[!c]at", "bat", true)
	expect_match(t, "[!c]at", "cat", false)

	expect_match(t, "/foo/**/[a-zA-Z]elp", "/foo//welp", true)
	expect_match(t, "/foo/**/[a-zA-Z]elp", "/foo/bar/Help", true)
}

@(private)
expect_parse :: proc(
	t: ^testing.T,
	glob: Pattern,
	err: Parse_Err,
	expected: []Node,
	loc := #caller_location,
) {
	testing.expect_value(t, err, nil, loc)
	testing.expect_value(t, len(glob.nodes), len(expected), loc)
	for node, i in expected {
		node_match(t, glob.nodes[i], node, loc)
	}
}

@(private)
node_match :: proc(t: ^testing.T, a, b: Node, loc := #caller_location) {
	switch a in a {
	case Node_Or:
		b, ok := b.(Node_Or)
		testing.expect_value(t, ok, true, loc)
		testing.expect_value(t, a.negate, b.negate, loc)
		testing.expect_value(t, len(a.patterns), len(b.patterns), loc)
		for grp, grp_i in a.patterns {
			for node, i in grp {
				node_match(t, b.patterns[grp_i][i], node, loc)
			}
		}
	case Node_Range:
		b, ok := b.(Node_Range)
		testing.expect_value(t, ok, true, loc)
		testing.expect_value(t, a, b, loc)
	case Node_Symbol:
		b, ok := b.(Node_Symbol)
		testing.expect_value(t, ok, true, loc)
		testing.expect_value(t, a, b, loc)
	case Node_Lit:
		b, ok := b.(Node_Lit)
		testing.expect_value(t, ok, true, loc)
		testing.expect_value(t, a, b, loc)
	}
}


package glob

import "core:log"
import "core:math"
import "core:mem/virtual"
import "core:unicode/utf8"

Pattern :: struct {
	arena: virtual.Arena,
	nodes: []Node,
}

Node :: union {
	Node_Symbol,
	Node_Lit,
	Node_Range,
	Node_Or,
}

Node_Lit :: string
Node_Symbol :: enum u8 {
	Slash,
	Globstar,
	Any_Char,
	Any_Text,
}
Node_Range :: struct {
	a, b: rune,
}
Node_Or :: struct {
	patterns: [][]Node,
	negate:   bool,
}

Parse_Err :: union #shared_nil {
	Maybe(Parse_Err_Pos),
	virtual.Allocator_Error,
}

Parse_Err_Pos :: struct {
	pos:     int,
	details: union {
		Parse_Err_Expected,
		Parse_Err_Unexpected_End,
	},
}
Parse_Err_Expected :: struct {
	expected: string,
	got:      string,
}
Parse_Err_Unexpected_End :: struct {}

pattern_from_string :: proc(pat: string) -> (pattern: Pattern, parse_err: Parse_Err) {
	err := virtual.arena_init_growing(&pattern.arena)
	if err != .None {
		return pattern, err
	}
	context.allocator = virtual.arena_allocator(&pattern.arena)
	parser := Parser {
		runes = utf8.string_to_runes(pat),
		ast   = make([dynamic]Node),
	}
	p := &parser

	for {
		node, err := scan(p)
		if err != nil {
			return pattern, err
		}
		if node == nil {
			break
		}
		append(&p.ast, node)
	}
	pattern.nodes = p.ast[:]
	return
}

pattern_destroy :: proc(prep: ^Pattern) {
	virtual.arena_destroy(&prep.arena)
}

match :: proc {
	match_string,
	match_pattern,
}

match_string :: proc(pattern: string, input: string) -> (bool, Parse_Err) {
	prep, err := pattern_from_string(pattern)
	if err != nil {
		return false, err
	}
	defer pattern_destroy(&prep)
	return match_pattern(prep, input)
}
match_pattern :: proc(
	prepared: Pattern,
	input: string,
) -> (
	bool,
	virtual.Allocator_Error,
) #optional_allocator_error {
	arena: virtual.Arena
	err := virtual.arena_init_growing(&arena)
	if err != .None {
		return false, err
	}
	alloc := virtual.arena_allocator(&arena)
	defer free_all(alloc)
	context.allocator = alloc
	runes := utf8.string_to_runes(input)
	defer delete(runes)
	_, match_res := _match(prepared.nodes, runes)
	return match_res, nil
}

_match :: proc(prepared: []Node, runes: []rune) -> (end_idx: int, matched: bool) {
	pos := 0
	for node, node_i in prepared {
		if pos >= len(runes) {return}

		switch t in node {
		case Node_Symbol:
			switch t {
			case .Slash:
				r := runes[pos]
				if r != '/' && r != '\\' {return}
				pos += 1
			case .Globstar:
				last_off := 0
				for r, i in runes[pos:] {
					if r == '/' || r == '\\' {
						last_off = i
						if end_idx, matched := _match(
							prepared[node_i + 1:],
							runes[pos + last_off:],
						); matched {
							return end_idx, true
						}
					}
				}
				pos = last_off + pos

			case .Any_Text:
				for r, i in runes[pos:] {
					if r == '/' || r == '\\' {
						break
					}
					if end_idx, matched := _match(prepared[node_i + 1:], runes[pos:]); matched {
						return end_idx, true
					}
					pos += 1
				}

			case .Any_Char:
				r := runes[pos]
				if r == '/' || r == '\\' {return}
				pos += 1

			}

		case Node_Lit:
			off := 0
			for r, i in t {
				if r != runes[pos + i] {return}
				off += 1
			}
			pos += off

		case Node_Range:
			r := runes[pos]
			if r < t.a || r > t.b {return}
			pos += 1

		case Node_Or:
			for grp in t.patterns {
				if matched_pos, matched := _match(cast([]Node)grp, runes[pos:]); matched {
					if t.negate {
						return pos, false
					}
					return matched_pos, true
				}
			}
			return pos, t.negate

		}
	}
	return pos, true
}

@(private)
Parser :: struct {
	pos:   int,
	curr:  rune,
	runes: []rune,
	ast:   [dynamic]Node,
}

@(private)
scan :: proc(p: ^Parser, break_on: rune = 0) -> (node: Node, err: Parse_Err) {
	r, ok := curr(p)
	if !ok || (break_on != 0 && r == break_on) {
		return nil, nil
	}
	switch r {
	case '/':
		adv(p)
		return Node_Symbol.Slash, nil
	case '*':
		if nr, ok := adv(p); ok && nr == '*' {
			adv(p)
			return Node_Symbol.Globstar, nil
		}
		return .Any_Text, nil
	case '{':
		grps := make([dynamic][]Node)
		grp := make([dynamic]Node)
		adv(p)
		for {
			inner_node, inner_err := scan(p, ',')
			if inner_err != nil {
				return nil, err
			}
			append(&grp, inner_node)
			if r, ok := curr(p); ok {
				if r == ',' {
					adv(p)
					append(&grps, grp[:])
					grp = make([dynamic]Node)
				}
				if r == '}' {
					adv(p)
					append(&grps, grp[:])
					return Node_Or{patterns = grps[:]}, nil
				}
			}
		}
		return nil, Maybe(Parse_Err_Pos)(
		Parse_Err_Pos{pos = p.pos, details = Parse_Err_Expected{expected = "}"}},
		)
	case '[':
		escaping := false
		r, ok := adv(p)
		if !ok {
			return nil, Maybe(Parse_Err_Pos)(
			Parse_Err_Pos{pos = p.pos, details = Parse_Err_Expected{expected = "]"}},
			)
		}
		groups, err := make([dynamic][]Node, context.temp_allocator)
		if err != .None {
			return nil, err
		}
		range: Maybe(Node_Range) = nil
		negate := false
		i := 0
		for {
			defer i += 1
			if !escaping {
				if i == 0 && r == '!' {
					negate = true
					r = adv(p) or_break
					continue
				}
				if r == ']' {
					adv(p)
					return Node_Or{negate = negate, patterns = groups[:]}, nil
				}
				if next(p) == '-' {
					range = Node_Range {
						a = r,
					}
					adv(p) or_break
					r = adv(p) or_break
					continue
				}
			}
			if !escaping && r == '\\' {
				escaping = true
			} else {
				slc := make([]Node, 1)
				if ran, ok := range.(Node_Range); ok {
					ran.b = r
					slc[0] = ran
				} else {
					slc[0] = utf8.runes_to_string({r})
				}
				append(&groups, slc)
				escaping = false
			}
			r = adv(p) or_break
		}
		return nil, Maybe(Parse_Err_Pos)(
		Parse_Err_Pos{pos = p.pos, details = Parse_Err_Expected{expected = "]"}},
		)
	case '?':
		adv(p)
		return .Any_Char, nil
	case:
		return scan_lit(p, break_on)
	}
	return
}

@(private)
scan_lit :: proc(p: ^Parser, break_on: rune = 0) -> (Node_Lit, Parse_Err) {
	escaping := false
	r, ok := curr(p)
	if !ok {
		return "", Maybe(Parse_Err_Pos)(
		Parse_Err_Pos{pos = p.pos, details = Parse_Err_Unexpected_End{}},
		)
	}
	runes, err := make([dynamic]rune, context.temp_allocator)
	if err != .None {
		return "", err
	}
	loop: for {
		if !escaping {
			switch r {
			case '/', '*', '{', '}', '[', ']', '?':
				break loop
			case break_on:
				if break_on != 0 {
					break loop
				}
			}
		}
		if !escaping && r == '\\' {
			escaping = true
		} else {
			append(&runes, r)
			escaping = false
		}
		r = adv(p) or_break
	}
	return utf8.runes_to_string(runes[:]), nil
}

@(private)
curr :: proc(p: ^Parser, idx: Maybe(int) = nil) -> (r: rune, ok: bool) #optional_ok {
	pos := idx.(int) or_else p.pos
	for pos >= len(p.runes) {
		return
	}
	return p.runes[pos], true
}
@(private)
adv :: proc(p: ^Parser, n := 1) -> (r: rune, ok: bool) #optional_ok {
	p.pos += n
	return curr(p)
}
@(private)
next :: proc(p: ^Parser, off := 1) -> (r: rune, ok: bool) #optional_ok {
	return curr(p, p.pos + off)
}


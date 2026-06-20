package checksum_helper

import "core:strings"
import "core:mem/virtual"
import "../vendor/glob"

Invalid_Pattern :: distinct Maybe(glob.Parse_Err)
Error :: union #shared_nil {
    Invalid_Pattern,
    virtual.Allocator_Error,
}

Matcher :: struct {
    allow: []glob.Pattern,
    block: []glob.Pattern,
}

matcher_is_blocked :: proc(m: Matcher, s: string) -> bool {
    for patt in m.block {
        if glob.match_pattern(patt, s) {
            return true
        }
    }

    return false
}

matcher_is_match :: proc(m: Matcher, s: string) -> bool {
    if (matcher_is_blocked(m, s)) {
        return false
    }

    if len(m.allow) == 0 {
        return true
    }

    for patt in m.allow {
        if glob.match_pattern(patt, s) {
            return true
        }
    }

    return false
}

matcher_destroy :: proc(m: ^Matcher) {
    sl := [][]glob.Pattern{m.allow, m.block}
    for patts in sl {
        for &patt in patts {
            glob.pattern_destroy(&patt)
        }
    }

    delete(m.allow)
    delete(m.block)
}

Matcher_Builder :: struct {
    allow: [dynamic]glob.Pattern,
    block: [dynamic]glob.Pattern,
}

when ODIN_OS == .Windows {
    PATH_SEPARATORS :: "\\/"
} else {
    PATH_SEPARATORS :: "/"
}

matcher_builder_allow :: proc(b: ^Matcher_Builder, pattern: string) -> Error {
    trimmed := strings.trim_right(pattern, PATH_SEPARATORS)
    pat, err := glob.pattern_from_string(trimmed)
    switch e in err {
    case Maybe(glob.Parse_Err_Pos):
        return Invalid_Pattern(e)
    case virtual.Allocator_Error:
        return e
    case:
    }

    append(&b.allow, pat)

    return nil
}

matcher_builder_block :: proc(b: ^Matcher_Builder, pattern: string) -> Error {
    trimmed := strings.trim_right(pattern, PATH_SEPARATORS)
    pat, err := glob.pattern_from_string(trimmed)
    switch e in err {
    case Maybe(glob.Parse_Err_Pos):
        return Invalid_Pattern(e)
    case virtual.Allocator_Error:
        return e
    case:
    }

    append(&b.block, pat)

    return nil
}

matcher_builder_build :: proc(b: ^Matcher_Builder) -> (m: Matcher) {
    m.allow = b.allow[:]
    m.block = b.block[:]
    return
}

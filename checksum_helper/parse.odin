package checksum_helper

import "core:bufio"
import "core:bytes"
import "core:encoding/hex"
import "core:io"
import "core:math"
import "core:mem/virtual"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:time"

parse :: proc(
	root: string,
	name: string,
	r: io.Reader,
) -> (
	result: Collection,
	err: CollectionError,
) {
	buf: [5 * 1024]u8 = ---
	b: bufio.Reader
	bufio.reader_init_with_buf(&b, r, buf[:])
	defer bufio.reader_destroy(&b)
	b.max_consecutive_empty_reads = 1

	// NOTE: use a local variable, so the defer can actually clean it up
	//       otherwise, if the named return value would be overwritten
	//       via `return Collection{}, ..` before the defer runs
	//       and the contents would be leaked
	c := collection_create(root, name) or_return
	free_collection := true
	defer if free_collection {
		collection_destroy(&c)
	}

	alloc := virtual.arena_allocator(&c.arena)
	seen_header := false
	version := 0
	for {
		// use _read_slice which does not allocate
		// in turn we need to use a buffer that is large enough
		// to always fit the complete line
		line, read_err := bufio.reader_read_slice(&b, '\n')
		if read_err == .No_Progress {
			break
		}
		if read_err == .EOF || read_err == .Unexpected_EOF {
			if len(line) == 0 {
				break
			}
		}
		if read_err == .Buffer_Full {
			return {}, Buffer_Full{}
		}

		line = bytes.trim_right(line, {'\r', '\n'})
		if len(line) == 0 {
			continue
		}

		if !seen_header {
			if line[0] == '#' {
				version = parse_header(line) or_return
				seen_header = true
				continue
			}
			seen_header = true
		}

		if line[0] == '#' {
			continue
		}

		file := parse_line(c, line, version, alloc) or_return
		ok := collection_insert(&c, file)
		if !ok {
			delete(file.path, alloc)
			delete(file.hash_bytes, alloc)
			return {}, Duplicate_Entry{}
		}
	}

	free_collection = false
	return c, nil
}

parse_header :: proc(line: []byte) -> (int, CollectionError) {
	header_prefix := "# version "
	as_bytes := transmute([]u8)(header_prefix)
	if !bytes.has_prefix(line, as_bytes) {
		return 0, nil
	}

	rest := bytes.trim(line[10:], {' ', '\t'})
	version, ok := strconv.parse_int(string(rest), 10)
	if !ok {
		return 0, Malformed_Header{}
	}
	return version, nil
}

parse_line :: proc(
	c: Collection,
	line: []byte,
	version: int,
	allocator := context.allocator,
) -> (
	f: File,
	err: CollectionError,
) {
	s := string(line)

	space_idx := strings.index_byte(s, ' ')
	if space_idx == -1 || space_idx == len(s) - 1 {
		return {}, Malformed_Hash_Line{line = s, index = 0}
	}

	all_fields := s[:space_idx]
	path := s[space_idx + 1:]

	num_fields := 3 if version == 0 else 4
	fields := strings.split_n(all_fields, ",", num_fields) or_return
	defer delete(fields)
	if len(fields) != num_fields {
		return {}, Malformed_Hash_Line{line = s, index = len(fields)}
	}

	// mtime
	mtime: time.Time
	if len(fields[0]) > 0 {
		mtime_f, ok := strconv.parse_f64(fields[0])
		if !ok {
			return {}, Malformed_Hash_Line{line = s, index = 0}
		}
		mtime = time_from_f64(mtime_f)
	}

	idx := 1
	size: u64
	if version == 1 {
		if len(fields[idx]) > 0 {
			size_u, ok := strconv.parse_u64(fields[idx])
			if !ok {
				return {}, Malformed_Hash_Line{line = s, index = idx}
			}
			size = size_u
		}
		idx += 1
	}

	// hash type
	ht, ht_ok := hash_type_from_identifier(fields[idx])
	if !ht_ok {
		return {}, Malformed_Hash_Line{line = s, index = idx}
	}
	idx += 1

	// hash
	hash, hash_ok := hex.decode(transmute([]byte)(fields[idx]), allocator)
	if !hash_ok {
		return {}, Malformed_Hash_Line{line = s, index = idx}
	}

	abs_path, join_err := filepath.join({c.root, path}, allocator)
	if join_err != nil {
		return {}, Malformed_Hash_Line{line = s, index = idx}
	}

	return File{path = abs_path, mtime = mtime, size = size, hash_type = ht, hash_bytes = hash},
		nil
}

time_from_f64 :: proc(f: f64) -> time.Time {
	int_part, frac_part := math.modf(f)
	mtime := time.unix(i64(int_part), i64(frac_part * 1_000_000_000.0))
	return mtime
}

package checksum_helper

import "core:bufio"
import "core:bytes"
import "core:encoding/hex"
import "core:io"
import "core:log"
import "core:mem/virtual"
import "core:path/filepath"

parse_single :: proc(
	root: string,
	name: string,
	hash_type: Hash_Type,
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

		hash_end_exclusive := bytes.index_byte(line, ' ')
		if hash_end_exclusive == -1 || hash_end_exclusive == (len(line) - 1) {
			return {}, Missing_Path{}
		}

		hash := line[:hash_end_exclusive]
		hash_bytes, hash_ok := hex.decode(hash, alloc)
		if !hash_ok {
			return {}, Invalid_Hash{}
		}

		path_relative := line[hash_end_exclusive + 1:]
		path_abs, join_err := filepath.join([]string{root, string(path_relative)}, alloc)
		if join_err != nil {
			return {}, join_err
		}

		ok := collection_insert(
			&c,
			File{path = path_abs, hash_type = hash_type, hash_bytes = hash_bytes},
		)
		if !ok {
			delete(path_abs, alloc)
			delete(hash_bytes, alloc)
			return {}, Duplicate_Entry{}
		}
	}

	free_collection = false
	return c, nil
}

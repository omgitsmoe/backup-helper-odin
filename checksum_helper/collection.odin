package checksum_helper

import "base:runtime"
import "core:mem/virtual"
import "core:path/filepath"
import "core:time"

Collection :: struct {
	root:         string,
	name:         string,
	mtime:        time.Time,
	path_to_file: map[string]File,
	arena:        virtual.Arena,
}

CollectionError :: union {
	Path_Not_Absolute,
	Missing_Path,
	Duplicate_Entry,
	Invalid_Hash,
	Buffer_Full,
	Malformed_Header,
	Malformed_Hash_Line,
	runtime.Allocator_Error,
}

Path_Not_Absolute :: struct {}
Missing_Path :: struct {}
Malformed_Header :: struct {}
Malformed_Hash_Line :: struct {
	line:  string,
	index: int,
}
Duplicate_Entry :: struct {}
Invalid_Hash :: struct {}
Buffer_Full :: struct {}

@(require_results)
collection_create :: proc(root: string, name: string) -> (c: Collection, err: CollectionError) {
	if !filepath.is_abs(root) {
		return Collection{}, Path_Not_Absolute{}
	}

	virtual.arena_init_growing(&c.arena) or_return
	arena_alloc := virtual.arena_allocator(&c.arena)

	normalized := filepath.clean(root, arena_alloc) or_return
	c.root = normalized
	c.name = name
	return
}

collection_destroy :: proc(c: ^Collection) {
	arena_alloc := virtual.arena_allocator(&c.arena)
	delete(c.path_to_file)
	free_all(arena_alloc)
}

// Either `file`'s "heap-allocated" fields were allocated using `c.arena`
// then `Collection` will handle freeing,
// othterwise the caller is responsible for managing `file`'s lifetime.
collection_update :: proc(c: ^Collection, file: File) {
	c.path_to_file[file.path] = file
}

// Either `file`'s "heap-allocated" fields were allocated using `c.arena`
// then `Collection` will handle freeing,
// othterwise the caller is responsible for managing `file`'s lifetime.
//
// As opposed to update, insert errors if the entry already exists.
collection_insert :: proc(c: ^Collection, file: File) -> bool {
	if file.path in c.path_to_file {
		return false
	}

	c.path_to_file[file.path] = file
	return true
}

collection_delete :: proc(c: ^Collection, key: string) {
	delete_key(&c.path_to_file, key)
}

collection_clear :: proc(c: ^Collection) {
	clear(&c.path_to_file)
}

Collection_Iter :: struct {
	c:     ^Collection,
	keys:  []string,
	index: int,
}

collection_files_iter :: proc(c: ^Collection) -> Collection_Iter {
	it := Collection_Iter {
		c = c,
	}
	it.keys = make([]string, len(c.path_to_file))
	i := 0
	for k in c.path_to_file {
		it.keys[i] = k
		i += 1
	}
	return it
}

collection_files_iter_destroy :: proc(it: ^Collection_Iter) {
	delete(it.keys)
}

collection_files_iter_next :: proc(it: ^Collection_Iter) -> (path: string, file: File, ok: bool) {
	if it.index >= len(it.keys) {
		return
	}
	path = it.keys[it.index]
	file = it.c.path_to_file[path]
	it.index += 1
	return path, file, true
}

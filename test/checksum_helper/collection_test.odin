package checksum_helper_test

import "../helpers"
import "core:mem/virtual"
import "core:path/filepath"
import "core:testing"
import ch "project:checksum_helper"

@(test)
collection_files_iter :: proc(t: ^testing.T) {
	abs := helpers.dummy_abs_dir()
	c, err := ch.collection_create(abs, "test")
	testing.expect(t, err == nil)
	defer ch.collection_destroy(&c)

	arena := virtual.arena_allocator(&c.arena)

	apath, aerr := filepath.join([]string{abs, "a.txt"}, arena)
	testing.expect(t, aerr == nil)
	bpath, berr := filepath.join([]string{abs, "b.txt"}, arena)
	testing.expect(t, berr == nil)
	cpath, cerr := filepath.join([]string{abs, "c.txt"}, arena)
	testing.expect(t, cerr == nil)

	ch.collection_insert(&c, ch.File{path = apath, size = 100, hash_type = .Sha2_256})
	ch.collection_insert(&c, ch.File{path = bpath, size = 200, hash_type = .Md5})
	ch.collection_insert(&c, ch.File{path = cpath, size = 300, hash_type = .Sha3_512})

	found: map[string]ch.File
	defer delete(found)

	it := ch.collection_files_iter(&c)
	defer ch.collection_files_iter_destroy(&it)

	for path, file in ch.collection_files_iter_next(&it) {
		found[path] = file
	}

	testing.expectf(t, len(found) == 3, "expected 3 files, got %v", len(found))
	testing.expectf(
		t,
		found[apath].size == 100,
		"a.txt: expected size 100, got %v",
		found[apath].size,
	)
	testing.expectf(
		t,
		found[bpath].size == 200,
		"b.txt: expected size 200, got %v",
		found[bpath].size,
	)
	testing.expectf(
		t,
		found[cpath].size == 300,
		"c.txt: expected size 300, got %v",
		found[cpath].size,
	)
	testing.expectf(t, found[apath].hash_type == .Sha2_256, "a.txt: expected hash_type Sha2_256")
	testing.expectf(t, found[bpath].hash_type == .Md5, "b.txt: expected hash_type Md5")
	testing.expectf(t, found[cpath].hash_type == .Sha3_512, "c.txt: expected hash_type Sha3_512")
}

@(test)
collection_files_iter_empty :: proc(t: ^testing.T) {
	c, err := ch.collection_create("/tmp", "empty")
	testing.expect(t, err == nil)
	defer ch.collection_destroy(&c)

	it := ch.collection_files_iter(&c)
	defer ch.collection_files_iter_destroy(&it)

	count := 0
	for _, _ in ch.collection_files_iter_next(&it) {
		count += 1
	}

	testing.expectf(t, count == 0, "expected 0 files in empty collection, got %v", count)
}

@(test)
collection_files_iter_after_delete :: proc(t: ^testing.T) {
	abs := helpers.dummy_abs_dir()
	c, err := ch.collection_create(abs, "delete-test")
	testing.expect(t, err == nil)
	defer ch.collection_destroy(&c)

	arena := virtual.arena_allocator(&c.arena)

	xpath, xerr := filepath.join([]string{abs, "x.txt"}, arena)
	testing.expect(t, xerr == nil)
	ypath, yerr := filepath.join([]string{abs, "y.txt"}, arena)
	testing.expect(t, yerr == nil)
	zpath, zerr := filepath.join([]string{abs, "z.txt"}, arena)
	testing.expect(t, zerr == nil)

	ch.collection_insert(&c, ch.File{path = xpath, size = 1})
	ch.collection_insert(&c, ch.File{path = ypath, size = 2})
	ch.collection_insert(&c, ch.File{path = zpath, size = 3})

	ch.collection_delete(&c, ypath)

	it := ch.collection_files_iter(&c)
	defer ch.collection_files_iter_destroy(&it)

	found: map[string]ch.File
	defer delete(found)

	for path, file in ch.collection_files_iter_next(&it) {
		found[path] = file
	}

	testing.expectf(t, len(found) == 2, "expected 2 files after delete, got %v", len(found))
	testing.expectf(t, xpath in found, "x.txt should exist")
	testing.expectf(t, zpath in found, "z.txt should exist")
	testing.expectf(t, ypath not_in found, "y.txt should be deleted")
}

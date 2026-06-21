package checksum_helper_test

import "core:bytes"
import "core:log"
import "core:mem/virtual"
import "core:strings"
import "core:testing"
import ch "project:checksum_helper"

Expected_File :: struct {
	path:       string,
	hash_type:  ch.Hash_Type,
	hash_bytes: []byte,
}

@(test)
parse_single :: proc(t: ^testing.T) {
	tests := []struct {
		input:          string,
		root:           string,
		name:           string,
		expected_err:   ch.CollectionError,
		expected_files: []Expected_File,
	} {
		{
			input = "aabb sub/a.txt\nccdd sub/b.txt\n",
			root = "/tmp",
			name = "my-col",
			expected_files = {
				{path = "/tmp/sub/a.txt", hash_type = .Sha2_256, hash_bytes = {0xaa, 0xbb}},
				{path = "/tmp/sub/b.txt", hash_type = .Sha2_256, hash_bytes = {0xcc, 0xdd}},
			},
		},
		{
			input = "aabb a.txt\n",
			root = "/tmp",
			name = "single",
			expected_files = {
				{path = "/tmp/a.txt", hash_type = .Sha2_256, hash_bytes = {0xaa, 0xbb}},
			},
		},
		{input = "", root = "/tmp", name = "empty", expected_files = {}},
		{
			input = "\n\naabb a.txt\n",
			root = "/tmp",
			name = "blank-lines",
			expected_files = {
				{path = "/tmp/a.txt", hash_type = .Sha2_256, hash_bytes = {0xaa, 0xbb}},
			},
		},
		{
			input = "aabb a.txt\r\n",
			root = "/tmp",
			name = "registered-nurse",
			expected_files = {
				{path = "/tmp/a.txt", hash_type = .Sha2_256, hash_bytes = {0xaa, 0xbb}},
			},
		},
		{input = "aabb \n", root = "/tmp", name = "x", expected_err = ch.Missing_Path{}},
		{input = "zzz a.txt\n", root = "/tmp", name = "x", expected_err = ch.Invalid_Hash{}},
		{
			input = "aabb a.txt\nccdd a.txt\n",
			root = "/tmp",
			name = "x",
			expected_err = ch.Duplicate_Entry{},
		},
		{
			input = "aabb a.txt\n",
			root = "relative",
			name = "x",
			expected_err = ch.Path_Not_Absolute{},
		},
	}

	for tt in tests {
		r: strings.Reader
		strings.reader_init(&r, tt.input)
		reader := strings.reader_to_stream(&r)

		c, err := ch.parse_single(tt.root, tt.name, .Sha2_256, reader)

		if tt.expected_err == nil {
			testing.expectf(t, err == nil, "[%q] expected no error, got %v", tt.input, err)
			testing.expectf(
				t,
				c.root == tt.root,
				"[%q] root: expected %q, got %q",
				tt.input,
				tt.root,
				c.root,
			)
			testing.expectf(
				t,
				c.name == tt.name,
				"[%q] name: expected %q, got %q",
				tt.input,
				tt.name,
				c.name,
			)
			testing.expectf(
				t,
				len(c.path_to_file) == len(tt.expected_files),
				"[%q] expected %d files, got %d",
				tt.input,
				len(tt.expected_files),
				len(c.path_to_file),
			)

			for fe in tt.expected_files {
				f, has := c.path_to_file[fe.path]
				testing.expectf(
					t,
					has,
					"[%q] expected file %q not found in collection",
					tt.input,
					fe.path,
				)
				testing.expectf(
					t,
					f.hash_type == fe.hash_type,
					"[%q] %q: expected hash_type %v, got %v",
					tt.input,
					fe.path,
					fe.hash_type,
					f.hash_type,
				)
				testing.expectf(
					t,
					bytes.equal(f.hash_bytes, fe.hash_bytes),
					"[%q] %q: expected hash %x, got %x",
					tt.input,
					fe.path,
					fe.hash_bytes,
					f.hash_bytes,
				)
			}
			ch.collection_destroy(&c)
		} else {
			// no free, so we test if parse_single free'd properly
			testing.expectf(t, err != nil, "[%q] expected error, got none", tt.input)
			testing.expectf(
				t,
				err == tt.expected_err,
				"[%q] expected %T, got %T",
				tt.input,
				tt.expected_err,
				err,
			)
		}
	}
}

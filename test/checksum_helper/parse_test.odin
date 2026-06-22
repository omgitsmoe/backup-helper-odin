package checksum_helper_test

import "core:bytes"
import "core:math"
import "core:strings"
import "core:testing"
import "core:time"
import ch "project:checksum_helper"

ParseExpectedFile :: struct {
	path:       string,
	mtime:      time.Time,
	size:       u64,
	hash_type:  ch.Hash_Type,
	hash_bytes: []byte,
}

@(test)
parse :: proc(t: ^testing.T) {
	success_cases := []struct {
		input: string,
		root:  string,
		name:  string,
		files: []ParseExpectedFile,
	} {
		{
			input = "1234567890.5,sha256,aabb a.txt\n",
			root = "/tmp",
			name = "v0-basic",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = ch.time_from_f64(1234567890.5),
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
		{
			input = ",sha256,aabb a.txt\n",
			root = "/tmp",
			name = "v0-no-mtime",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = time.Time{},
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
		{
			input = "# version 1\n1234567890.5,123,sha256,aabb a.txt\n",
			root = "/tmp",
			name = "v1-basic",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = ch.time_from_f64(1234567890.5),
					size = 123,
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
		{
			input = "# version 1\n,123,sha256,aabb a.txt\n",
			root = "/tmp",
			name = "v1-no-mtime",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = time.Time{},
					size = 123,
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
		{
			input = "# version 1\n,,sha256,aabb a.txt\n",
			root = "/tmp",
			name = "v1-no-mtime-size",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = time.Time{},
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
		{
			input = "1234567890.5,sha256,aabb sub/a.txt\n987654321.5,sha3_512,ccdd sub/b.txt\n",
			root = "/tmp",
			name = "two-files",
			files = {
				{
					path = "/tmp/sub/a.txt",
					mtime = ch.time_from_f64(1234567890.5),
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
				{
					path = "/tmp/sub/b.txt",
					mtime = ch.time_from_f64(987654321.5),
					hash_type = .Sha3_512,
					hash_bytes = {0xcc, 0xdd},
				},
			},
		},
		{
			input = "# comment\n\n# version 0\n1234567890.5,sha256,aabb a.txt\n",
			root = "/tmp",
			name = "comment-header",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = ch.time_from_f64(1234567890.5),
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
		{
			input = "1234567890.5,sha256,aabb a.txt\n# trailing comment\n",
			root = "/tmp",
			name = "trailing-comment",
			files = {
				{
					path = "/tmp/a.txt",
					mtime = ch.time_from_f64(1234567890.5),
					hash_type = .Sha2_256,
					hash_bytes = {0xaa, 0xbb},
				},
			},
		},
	}

	for tt in success_cases {
		r: strings.Reader
		strings.reader_init(&r, tt.input)
		reader := strings.reader_to_stream(&r)

		c, err := ch.parse(tt.root, tt.name, reader)
		testing.expectf(t, err == nil, "[%q] expected no error, got %v", tt.name, err)
		defer ch.collection_destroy(&c)

		testing.expectf(
			t,
			len(c.path_to_file) == len(tt.files),
			"[%q] expected %d files, got %d",
			tt.name,
			len(tt.files),
			len(c.path_to_file),
		)

		for fe in tt.files {
			f, has := c.path_to_file[fe.path]
			testing.expectf(t, has, "[%q] expected file %q not found", tt.name, fe.path)
			testing.expectf(t, f.mtime == fe.mtime, "[%q] %q: mtime mismatch", tt.name, fe.path)
			testing.expectf(t, f.size == fe.size, "[%q] %q: size mismatch", tt.name, fe.path)
			testing.expectf(
				t,
				f.hash_type == fe.hash_type,
				"[%q] %q: hash_type mismatch",
				tt.name,
				fe.path,
			)
			testing.expectf(
				t,
				bytes.equal(f.hash_bytes, fe.hash_bytes),
				"[%q] %q: hash mismatch",
				tt.name,
				fe.path,
			)
		}
	}

	error_cases := []struct {
		input:      string,
		root:       string,
		name:       string,
		expected:   ch.CollectionError,
		line_index: int,
	} {
		{input = "sha256only\n", root = "/tmp", name = "no-space", line_index = 0},
		{input = ",\n", root = "/tmp", name = "no-space-fields", line_index = 0},
		{
			input = "1234567890.5,sha256,zz a.txt\n",
			root = "/tmp",
			name = "bad-hex",
			line_index = 2,
		},
		{
			input = "1234567890.5,invalid_ht,aabb a.txt\n",
			root = "/tmp",
			name = "bad-hash-type",
			line_index = 1,
		},
		{input = ":)bad,sha256,aabb a.txt\n", root = "/tmp", name = "bad-mtime", line_index = 0},
		{
			input = "1234567890.5,sha256,aabb a.txt\n1234567890.5,sha256,aabb a.txt\n",
			root = "/tmp",
			name = "duplicate",
			expected = ch.Duplicate_Entry{},
			line_index = -1,
		},
		{
			input = "1234567890.5,aabb a.txt\n",
			root = "/tmp",
			name = "too-few-fields",
			line_index = 2,
		},
	}

	for tt in error_cases {
		r: strings.Reader
		strings.reader_init(&r, tt.input)
		reader := strings.reader_to_stream(&r)

		c, err := ch.parse(tt.root, tt.name, reader)
		testing.expectf(t, err != nil, "[%q] expected error, got none", tt.name)

		if tt.line_index >= 0 {
			mle, ok := err.(ch.Malformed_Hash_Line)
			testing.expectf(t, ok, "[%q] expected Malformed_Hash_Line, got %T", tt.name, err)
			testing.expectf(
				t,
				mle.index == tt.line_index,
				"[%q] expected index %d, got %d",
				tt.name,
				tt.line_index,
				mle.index,
			)
		} else {
			testing.expectf(
				t,
				err == tt.expected,
				"[%q] expected %T, got %T",
				tt.name,
				tt.expected,
				err,
			)
		}
	}
}

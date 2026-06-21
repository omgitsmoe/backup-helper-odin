package checksum_helper_test

import "../helpers"
import "core:encoding/hex"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:testing"
import ch "project:checksum_helper"

TEST_CONTENT :: "hello"

@(test)
hash_file :: proc(t: ^testing.T) {
	test_dir := helpers.temp_dir(t)
	defer delete(test_dir)

	path, join_err := filepath.join({test_dir, "test_file"})
	testing.expect(t, join_err == nil)
	defer delete(path)

	testing.expect(t, os.write_entire_file(path, TEST_CONTENT) == nil)

	tests := []struct {
		ht:       ch.Hash_Type,
		expected: string,
	} {
		{.Md5, "5d41402abc4b2a76b9719d911017c592"},
		{.Sha_1, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d"},
		{.Sha2_224, "ea09ae9cc6768c50fcee903ed054556e5bfc8347907f12598aa24193"},
		{.Sha2_256, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"},
		{
			.Sha2_384,
			"59e1748777448c69de6b800d7a33bbfb9ff1b463e44354c3553bcdb9c666fa90125a3c79f90397bdf5f6a13de828684f",
		},
		{
			.Sha2_512,
			"9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043",
		},
		{.Sha3_224, "b87f88c72702fff1748e58b87e9141a42c0dbedc29a78cb0d4a5cd81"},
		{.Sha3_256, "3338be694f50c5f338814986cdf0686453a888b84f424d792af4b9202398f392"},
		{
			.Sha3_384,
			"720aea11019ef06440fbf05d87aa24680a2153df3907b23631e7177ce620fa1330ff07c0fddee54699a4c3ee0ee9d887",
		},
		{
			.Sha3_512,
			"75d527c368f2efe848ecf6b073a36767800805e9eef2b1857d5f984f036eb6df891d75f72d9b154518c1cd58835286d1da9a38deba3de98b5a53e5ed78a84976",
		},
	}

	for tt in tests {
		digest, ok := ch.hash_file(tt.ht, path)
		testing.expectf(t, ok, "hash_file(%v): ok = false", tt.ht)

		hex_bytes, enc_err := hex.encode(digest)
		testing.expectf(t, enc_err == nil, "hash_file(%v): hex encode failed", tt.ht)
		hex_str := string(hex_bytes)

		testing.expectf(
			t,
			hex_str == tt.expected,
			"hash_file(%v): expected %q, got %q",
			tt.ht,
			tt.expected,
			hex_str,
		)

		delete(hex_bytes)
		delete(digest)
	}
}

@(test)
hash_file_handle :: proc(t: ^testing.T) {
	test_dir := helpers.temp_dir(t)
	defer delete(test_dir)

	path, join_err := filepath.join({test_dir, "test_file"})
	testing.expect(t, join_err == nil)
	defer delete(path)

	testing.expect(t, os.write_entire_file(path, TEST_CONTENT) == nil)

	tests := []struct {
		ht:       ch.Hash_Type,
		expected: string,
	} {
		{.Md5, "5d41402abc4b2a76b9719d911017c592"},
		{.Sha_1, "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d"},
		{.Sha2_224, "ea09ae9cc6768c50fcee903ed054556e5bfc8347907f12598aa24193"},
		{.Sha2_256, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"},
		{
			.Sha2_384,
			"59e1748777448c69de6b800d7a33bbfb9ff1b463e44354c3553bcdb9c666fa90125a3c79f90397bdf5f6a13de828684f",
		},
		{
			.Sha2_512,
			"9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043",
		},
		{.Sha3_224, "b87f88c72702fff1748e58b87e9141a42c0dbedc29a78cb0d4a5cd81"},
		{.Sha3_256, "3338be694f50c5f338814986cdf0686453a888b84f424d792af4b9202398f392"},
		{
			.Sha3_384,
			"720aea11019ef06440fbf05d87aa24680a2153df3907b23631e7177ce620fa1330ff07c0fddee54699a4c3ee0ee9d887",
		},
		{
			.Sha3_512,
			"75d527c368f2efe848ecf6b073a36767800805e9eef2b1857d5f984f036eb6df891d75f72d9b154518c1cd58835286d1da9a38deba3de98b5a53e5ed78a84976",
		},
	}

	for tt in tests {
		f, open_err := os.open(path)
		testing.expectf(t, open_err == nil, "hash_file_handle(%v): open failed", tt.ht)

		digest, ok := ch.hash_file_handle(tt.ht, f)
		os.close(f)

		testing.expectf(t, ok, "hash_file_handle(%v): ok = false", tt.ht)

		hex_bytes, enc_err := hex.encode(digest)
		testing.expectf(t, enc_err == nil, "hash_file_handle(%v): hex encode failed", tt.ht)
		hex_str := string(hex_bytes)

		testing.expectf(
			t,
			hex_str == tt.expected,
			"hash_file_handle(%v): expected %q, got %q",
			tt.ht,
			tt.expected,
			hex_str,
		)

		delete(hex_bytes)
		delete(digest)
	}
}

@(test)
hash_file_empty :: proc(t: ^testing.T) {
	test_dir := helpers.temp_dir(t)
	defer delete(test_dir)

	path, join_err := filepath.join({test_dir, "empty_file"})
	testing.expect(t, join_err == nil)
	defer delete(path)

	testing.expect(t, os.write_entire_file(path, "") == nil)

	digest, ok := ch.hash_file(.Sha2_256, path)
	testing.expect(t, ok)

	hex_bytes, enc_err := hex.encode(digest)
	testing.expect(t, enc_err == nil)
	hex_str := string(hex_bytes)

	testing.expectf(
		t,
		hex_str == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		"hash_file empty: expected %q, got %q",
		"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		hex_str,
	)

	delete(hex_bytes)
	delete(digest)
}

@(test)
hash_file_nonexistent :: proc(t: ^testing.T) {
	digest, ok := ch.hash_file(.Sha2_256, "/nonexistent/__test__path__")
	testing.expect(t, !ok)
	testing.expect(t, digest == nil)
}

@(test)
hash_file_callback :: proc(t: ^testing.T) {
	test_dir := helpers.temp_dir(t)
	defer delete(test_dir)

	path, join_err := filepath.join({test_dir, "test_file"})
	testing.expect(t, join_err == nil)
	defer delete(path)

	testing.expect(t, os.write_entire_file(path, TEST_CONTENT) == nil)

	expected_hash := "5d41402abc4b2a76b9719d911017c592"

	Callback_Data :: struct {
		read:  u64,
		total: u64,
	}
	actual_callbacks: [dynamic]Callback_Data
	digest, ok := ch.hash_file(
		.Md5,
		path,
		1337,
		proc(read: u64, total: u64, userdata: rawptr) -> bool {
			arr := cast(^[dynamic]Callback_Data)userdata
			append(arr, Callback_Data{read = read, total = total})
			return true
		},
		&actual_callbacks,
	)
	defer delete(actual_callbacks)
	defer delete(digest)
	testing.expectf(t, ok, "hash_file(%v): ok = false", ch.Hash_Type.Md5)

	hex_bytes, enc_err := hex.encode(digest)
	defer delete(hex_bytes)
	testing.expectf(t, enc_err == nil, "hash_file(%v): hex encode failed", ch.Hash_Type.Md5)
	hex_str := string(hex_bytes)

	testing.expectf(
		t,
		hex_str == expected_hash,
		"hash_file(%v): expected %q, got %q",
		ch.Hash_Type.Md5,
		expected_hash,
		hex_str,
	)
	testing.expect(
		t,
		slice.equal(
			[]Callback_Data {
				// 1337 from hash_file param
				Callback_Data{read = 5, total = 1337},
			},
			actual_callbacks[:],
		),
	)
}

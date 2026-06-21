package checksum_helper

import "core:time"

File :: struct {
	path:       string,
	mtime:      time.Time,
	size:       u64,
	hash_type:  Hash_Type,
	hash_bytes: []u8,
}

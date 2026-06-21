package checksum_helper

import "core:os"
import "core:io"
import "core:crypto/hash"


Hash_Type :: enum {
    Md5,
    Sha_1,
    Sha2_224,
    Sha2_256,
    Sha2_384,
    Sha2_512,
    Sha3_224,
    Sha3_256,
    Sha3_384,
    Sha3_512,
}

Progress_Callback :: #type proc(read: u64, total: u64, userdata: rawptr) -> bool

hash_type_to_algorithm :: proc(ht: Hash_Type) -> hash.Algorithm {
    switch ht {
    case .Md5:      return .Insecure_MD5
    case .Sha_1:    return .Insecure_SHA1
    case .Sha2_224: return .SHA224
    case .Sha2_256: return .SHA256
    case .Sha2_384: return .SHA384
    case .Sha2_512: return .SHA512
    case .Sha3_224: return .SHA3_224
    case .Sha3_256: return .SHA3_256
    case .Sha3_384: return .SHA3_384
    case .Sha3_512: return .SHA3_512
    }
    panic("unknown hash type")
}

hash_type_to_identifier :: proc(h: Hash_Type) -> string {
    switch h {
    case .Md5: return "md5"
    case .Sha_1: return "sha1"
    case .Sha2_224: return "sha224"
    case .Sha2_256: return "sha256"
    case .Sha2_384: return "sha384"
    case .Sha2_512: return "sha512"
    case .Sha3_224: return "sha3_224"
    case .Sha3_256: return "sha3_256"
    case .Sha3_384: return "sha3_384"
    case .Sha3_512: return "sha3_512"
    }

    panic("unkown hash type")
}

hash_type_from_identifier :: proc(s: string) -> (Hash_Type, bool) {
    switch s {
    case "md5": return .Md5, true
    case "sha1": return .Sha_1, true
    case "sha224": return .Sha2_224, true
    case "sha256": return .Sha2_256, true
    case "sha384": return .Sha2_384, true
    case "sha512": return .Sha2_512, true
    case "sha3_224": return .Sha3_224, true
    case "sha3_256": return .Sha3_256, true
    case "sha3_384": return .Sha3_384, true
    case "sha3_512": return .Sha3_512, true
    }

    return Hash_Type{}, false
}

hash_file_handle :: proc(
    ht: Hash_Type, f: ^os.File, total: u64 = 0,
    progress_cb: Progress_Callback = nil, userdata: rawptr = nil
) -> (digest: []byte, ok: bool) {
    algo := hash_type_to_algorithm(ht)
    digest_size := hash.DIGEST_SIZES[algo]

    total_bytes := total
    if progress_cb != nil && total_bytes == 0 {
        fi, _ := os.fstat(f, context.temp_allocator)
        total_bytes = u64(fi.size)
    }

    ctx: hash.Context
    hash.init(&ctx, algo)
    defer hash.reset(&ctx)

    buf: [64 * 1024]byte
    processed: u64 = 0
    for {
        n, err := os.read(f, buf[:])
        if n > 0 {
            hash.update(&ctx, buf[:n])
            processed += u64(n)
            if progress_cb != nil {
                if !progress_cb(processed, total_bytes, userdata) {
                    return nil, false
                }
            }
        }
        if err == io.Error.EOF {
            break
        }
        if err != nil {
            return nil, false
        }
        if n == 0 {
            break
        }
    }

    digest = make([]byte, digest_size)
    hash.final(&ctx, digest)
    return digest, true
}

hash_file :: proc(
    ht: Hash_Type, path: string, total: u64 = 0,
    progress_cb: Progress_Callback = nil, userdata: rawptr = nil
) -> (digest: []byte, ok: bool) {
    f, err := os.open(path)
    if err != nil {
        return nil, false
    }
    defer os.close(f)
    return hash_file_handle(ht, f, total, progress_cb, userdata)
}

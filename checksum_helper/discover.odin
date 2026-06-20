package checksum_helper

import "core:fmt"
import "core:strings"
import "core:os"

Filtered_Walker :: struct {
    // TODO add matcher
    inner: os.Walker,
}

File_Status :: enum {
    Ok,
    Ignored_Special_File,
    Ignored_Matcher,
    Ignored_Predicate,
    Skipped_Directory,
}

Filtered_File_Info :: struct {
    fi: os.File_Info,
    status: File_Status,
}

filtered_walker_create :: proc(path: string) -> (w: Filtered_Walker) {
    os.walker_init(&w.inner, path)
    return
}

filtered_walker_destroy :: proc(w: ^Filtered_Walker) {
    os.walker_destroy(&w.inner)
}

filtered_walker_error :: proc(w: ^Filtered_Walker) -> (string, os.Error) {
    return os.walker_error(&w.inner)
}

filtered_walker_skip_dir :: proc(w: ^Filtered_Walker) {
    os.walker_skip_dir(&w.inner)
}

// can be used with Odin's for .. in loop
@(require_results)
filtered_walker_walk :: proc(w: ^Filtered_Walker) -> (fi: Filtered_File_Info, ok: bool) {
    for {
        fi.fi, ok = os.walker_walk(&w.inner)

        if !ok {
            return
        }

        if path, err := os.walker_error(&w.inner); err != nil {
            // TODO
            fmt.eprintfln("failed walking %s: %s", path, err)
        }

        switch fi.fi.type {
        case .Regular:
        case .Directory:
            fi.status = .Ok

        case .Undetermined:
        case .Symlink:
        case .Named_Pipe:
        case .Socket:
        case .Block_Device:
        case .Character_Device:
            fi.status = .Ignored_Special_File
        }

        // TODO
        // Skip a directory:
        // if strings.has_suffix(fi.fi.fullpath, ".git") {
        //     filtered_walker_skip_dir(w)
        //     continue
        // }

        break
    }

    return
}

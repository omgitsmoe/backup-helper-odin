package checksum_helper

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"

Filtered_Walker :: struct {
	inner:              os.Walker,
	root:               string,
	matcher:            Matcher,
	last_relative_path: string,
}

File_Status :: enum {
	Ok,
	Ignored_Special_File,
	Ignored_Matcher,
}

Filtered_File_Info :: struct {
	fi:            os.File_Info,
	status:        File_Status,
	relative_path: string,
}

Filtered_Walker_Error :: union {
	runtime.Allocator_Error,
}

filtered_walker_create :: proc(
	path: string,
	matcher: Matcher,
) -> (
	w: Filtered_Walker,
	err: Filtered_Walker_Error,
) {
	os.walker_init(&w.inner, path)
	w.root = filepath.clean(path) or_return
	w.matcher = matcher
	return
}

filtered_walker_destroy :: proc(w: ^Filtered_Walker) {
	os.walker_destroy(&w.inner)
	delete(w.root)
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

		if w.last_relative_path != "" {
			delete(w.last_relative_path, context.allocator)
			w.last_relative_path = ""
		}

		if !ok {
			return
		}

		if path, err := os.walker_error(&w.inner); err != nil {
			// TODO
			fmt.eprintfln("failed walking %s: %s", path, err)
		}

		switch fi.fi.type {
		case .Regular, .Directory:
			{
				fi.status = .Ok

				rel, err := os.get_relative_path(w.root, fi.fi.fullpath, context.allocator)
				w.last_relative_path = rel
				fi.relative_path = rel

				if fi.fi.type == .Directory {
					if matcher_is_blocked(w.matcher, rel) {
						fi.status = .Ignored_Matcher
						filtered_walker_skip_dir(w)
					}

					return
				}

				if !matcher_is_match(w.matcher, rel) {
					fi.status = .Ignored_Matcher
				}
			}

		case .Undetermined, .Symlink, .Named_Pipe, .Socket, .Block_Device, .Character_Device:
			fi.status = .Ignored_Special_File
		}

		break
	}

	return
}

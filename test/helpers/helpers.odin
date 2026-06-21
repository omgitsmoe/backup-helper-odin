package test_helpers

import "core:path/filepath"
import "core:testing"
import "core:time"
import "core:os"

Test_File :: struct {
    relative_path: string,
    contents: string,
    mtime: time.Time
}

create_test_files :: proc(t: ^testing.T, root: string, files: []Test_File) {
    for file in files {
        abs, err := filepath.join({ root, file.relative_path })
        defer delete(abs)

        testing.expect(t, err == nil)

        contents := file.contents
        if len(file.contents) == 0 {
            contents = file.relative_path
        }

        dirname := filepath.dir(abs)
        mkdir_err := os.make_directory_all(dirname)
        testing.expect(t, mkdir_err == .Exist || mkdir_err == nil)

        write_err := os.write_entire_file(abs, contents)
        testing.expect(t, write_err == nil)

        if file.mtime != time.Time({}) {
            err := os.change_times(abs, file.mtime, file.mtime)
            testing.expect(t, err == nil)
        }
    }
}

temp_dir :: proc(t: ^testing.T, loc := #caller_location) -> string {
    cwd, _ := os.get_working_directory(context.temp_allocator)

    rel, err := filepath.rel(cwd, loc.file_path)
    defer delete(rel)
    testing.expect(t, err == nil)

    test_dir, join_err := filepath.join(
        []string{ cwd, ".test-cases", rel, loc.procedure }, context.allocator)
    testing.expect(t, join_err == nil)

    rmdir_err := os.remove_all(test_dir)
    testing.expect(t, rmdir_err == .Not_Exist || rmdir_err == nil)

    mkdir_err := os.make_directory_all(test_dir)
    testing.expect(t, mkdir_err == nil)

    return test_dir
}

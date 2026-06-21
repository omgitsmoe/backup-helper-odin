package checksum_helper_test

import "../helpers"
import "core:log"
import "core:strings"
import "core:testing"
import ch "project:checksum_helper"

@(test)
filtered_walker :: proc(t: ^testing.T) {
	test_dir := helpers.temp_dir(t)
	defer delete(test_dir)

	helpers.create_test_files(
		t,
		test_dir,
		[]helpers.Test_File {
			{relative_path = "foo/bar/file.txt"},
			{relative_path = "foo/bar/xer.bin"},
			{relative_path = "foo/xer/file.txt"},
			{relative_path = "foo/file.txt"},
			{relative_path = "foo/baz.bin"},
			{relative_path = "file.txt"},
			{relative_path = "other.bin"},
			{relative_path = "bar/file.txt"},
			{relative_path = "bar/other.bin"},
		},
	)

	Expected :: struct {
		relative_path: string,
		status:        ch.File_Status,
	}

	// TODO special file
	tests := []struct {
		allow:    []string,
		block:    []string,
		expected: []Expected,
	} {
		{
			expected = {
				{relative_path = "bar", status = .Ok},
				{relative_path = "file.txt", status = .Ok},
				{relative_path = "foo", status = .Ok},
				{relative_path = "other.bin", status = .Ok},
				{relative_path = "bar/file.txt", status = .Ok},
				{relative_path = "bar/other.bin", status = .Ok},
				{relative_path = "foo/bar", status = .Ok},
				{relative_path = "foo/baz.bin", status = .Ok},
				{relative_path = "foo/file.txt", status = .Ok},
				{relative_path = "foo/xer", status = .Ok},
				{relative_path = "foo/bar/file.txt", status = .Ok},
				{relative_path = "foo/bar/xer.bin", status = .Ok},
				{relative_path = "foo/xer/file.txt", status = .Ok},
			},
		},
		{
			allow = []string{"bar/**/*"},
			expected = {
				{relative_path = "bar", status = .Ok},
				{relative_path = "file.txt", status = .Ignored_Matcher},
				{relative_path = "foo", status = .Ignored_Matcher},
				{relative_path = "other.bin", status = .Ignored_Matcher},
				{relative_path = "bar/file.txt", status = .Ok},
				{relative_path = "bar/other.bin", status = .Ok},
				{relative_path = "foo/bar", status = .Ignored_Matcher},
				{relative_path = "foo/baz.bin", status = .Ignored_Matcher},
				{relative_path = "foo/file.txt", status = .Ignored_Matcher},
				{relative_path = "foo/xer", status = .Ignored_Matcher},
				{relative_path = "foo/bar/file.txt", status = .Ignored_Matcher},
				{relative_path = "foo/bar/xer.bin", status = .Ignored_Matcher},
				{relative_path = "foo/xer/file.txt", status = .Ignored_Matcher},
			},
		},
		{
			allow = []string{"bar/**/*"},
			block = []string{"foo/"},
			expected = {
				{relative_path = "bar", status = .Ok},
				{relative_path = "file.txt", status = .Ignored_Matcher},
				{relative_path = "foo", status = .Ignored_Matcher},
				{relative_path = "other.bin", status = .Ignored_Matcher},
				{relative_path = "bar/file.txt", status = .Ok},
				{relative_path = "bar/other.bin", status = .Ok},
			},
		},
	}


	for tt in tests {
		matcher, err := ch.matcher_from(tt.allow, tt.block)
		defer ch.matcher_destroy(&matcher)
		testing.expect(t, err == nil)

		w, werr := ch.filtered_walker_create(test_dir, matcher)
		testing.expect(t, werr == nil)
		defer ch.filtered_walker_destroy(&w)

		actual: [dynamic]Expected
		defer {
			for s in actual {
				delete(s.relative_path)
			}
			delete(actual)
		}

		for fi in ch.filtered_walker_walk(&w) {
			rel := strings.clone(fi.relative_path)
			append(&actual, Expected{relative_path = rel, status = fi.status})
		}

		log.debugf("got %#v", actual)
		testing.expectf(
			t,
			len(tt.expected) == len(actual),
			"expected length %v, got %v",
			len(tt.expected),
			len(actual),
		)
		for a, idx in actual {
			testing.expectf(
				t,
				tt.expected[idx].relative_path == a.relative_path,
				"[%v] expected relative_path %v, got %v",
				idx,
				tt.expected[idx].relative_path,
				a.relative_path,
			)
		}
	}
}

@(test)
filtered_walker_skips_dir :: proc(t: ^testing.T) {
	test_dir := helpers.temp_dir(t)
	defer delete(test_dir)

	helpers.create_test_files(
		t,
		test_dir,
		[]helpers.Test_File {
			{relative_path = "foo/bar/file.txt"},
			{relative_path = "foo/bar/xer.bin"},
			{relative_path = "foo/xer/file.txt"},
			{relative_path = "foo/file.txt"},
			{relative_path = "foo/baz.bin"},
			{relative_path = "file.txt"},
			{relative_path = "other.bin"},
			{relative_path = "bar/file.txt"},
			{relative_path = "bar/other.bin"},
		},
	)

	Expected :: struct {
		relative_path: string,
		status:        ch.File_Status,
	}

	expected := []Expected {
		{relative_path = "bar", status = .Ok},
		{relative_path = "file.txt", status = .Ok},
		{relative_path = "foo", status = .Ok},
		{relative_path = "other.bin", status = .Ok},
	}

	matcher, err := ch.matcher_from([]string{}, []string{})
	defer ch.matcher_destroy(&matcher)
	testing.expect(t, err == nil)

	w, werr := ch.filtered_walker_create(test_dir, matcher)
	testing.expect(t, werr == nil)
	defer ch.filtered_walker_destroy(&w)

	actual: [dynamic]Expected
	defer {
		for s in actual {
			delete(s.relative_path)
		}
		delete(actual)
	}

	for fi in ch.filtered_walker_walk(&w) {
		if (fi.fi.type == .Directory) {
			ch.filtered_walker_skip_dir(&w)
		}
		rel := strings.clone(fi.relative_path)
		append(&actual, Expected{relative_path = rel, status = fi.status})
	}

	log.debugf("got %#v", actual)
	testing.expectf(
		t,
		len(expected) == len(actual),
		"expected length %v, got %v",
		len(expected),
		len(actual),
	)
	for a, idx in actual {
		testing.expectf(
			t,
			expected[idx].relative_path == a.relative_path,
			"[%v] expected relative_path %v, got %v",
			idx,
			expected[idx].relative_path,
			a.relative_path,
		)
	}
}

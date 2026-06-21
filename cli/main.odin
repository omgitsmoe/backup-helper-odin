package main

import "core:testing"
import "core:fmt"

import ch "../checksum_helper"

main :: proc() {
	fmt.println("Hellope!")

    walker := ch.filtered_walker_create(".", ch.Matcher{})
    defer ch.filtered_walker_destroy(&walker)

    for info in ch.filtered_walker_walk(&walker) {
        fmt.printfln("%#v: status(%#v)", info.fi.fullpath, info.status)
    }
}

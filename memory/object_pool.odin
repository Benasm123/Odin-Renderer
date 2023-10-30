package memory

import "core:mem"
import "core:fmt"

ObjectPool :: struct($T : typeid, $size : int) {
    objects : [size]T,
}
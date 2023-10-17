package vulkan_renderer

import "core:fmt"
import "core:os"
import "core:path/filepath"

read_spriv :: proc(file_name : string) -> (code : []u8, err : ErrorCode = .SUCCESS) {

    parts : []string = {"Shaders/compiled", file_name}
    path : string = filepath.join(parts)

    file_contents, ok := os.read_entire_file(path, context.allocator)

    if (!ok) {
        fmt.println("Failed to read file ", file_name)
        return {}, .FAILURE
    }

    return file_contents, err
}
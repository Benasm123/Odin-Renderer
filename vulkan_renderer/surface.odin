package vulkan_renderer

import "core:fmt"
import vk "vendor:vulkan"
import sdl "vendor:sdl2"

create_surface :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    sdl.Vulkan_CreateSurface(window, instance, &surface)
    return
}
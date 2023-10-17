package main

import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:math"
import "core:time"
import bdm "math_utils"
import vkr "vulkan_renderer"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

Vec3 ::[3]f32

main :: proc() {
	ctx: vkr.Context

	sdl.Init(sdl.INIT_VIDEO)
	ctx.window = sdl.CreateWindow("Project B", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 1200, 800, sdl.WINDOW_VULKAN + sdl.WINDOW_RESIZABLE)

	if vkr.init_renderer(&ctx) != .SUCCESS {
		fmt.println("Failed to initialise renderer")
		os.exit(1)
	}
	defer {
		vkr.destroy_renderer(&ctx)
		sdl.DestroyWindow(ctx.window)
		sdl.Quit()
	}

	event: sdl.Event

	last_tick := time.now()

	engine_loop: for {
		for sdl.PollEvent(&event) == true {
			#partial switch event.type {
			case .QUIT:
				break engine_loop
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
					case .W:
					case .A:
					case .S:
					case .D:
				}
			}
		}

		current := time.now()
		delta_time := time.duration_milliseconds(time.diff(last_tick, current))
		last_tick = current

		vkr.render(&ctx)
	}

	fmt.println("Application Shutting Down!")
}
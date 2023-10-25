package main

import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:math"
import "core:time"
import "core:strings"
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

	// MARKER TEST
	mesh := vkr.create_mesh_from_file(&ctx, "TommyGun.obj")

	mesh.transform.position = {0, 0, 0}

	append(&ctx.meshes, mesh)
	// MARKER END TEST

	event: sdl.Event

	last_tick := time.now()

	camera_velocity : [3]f32
	key_pressed : [4]bool
	last_mouse_pos : [2]i32
	sdl.GetMouseState(&last_mouse_pos.x, &last_mouse_pos.y)
	camera_rotation : [3]f32

	ctx.camera_direction = {0, 0, -1}

	engine_loop: for {
		current := time.now()
		delta_time := time.duration_milliseconds(time.diff(last_tick, current))
		last_tick = current

		new_mouse_pos : [2]i32
		sdl.GetMouseState(&new_mouse_pos.x, &new_mouse_pos.y)

		mouse_movement : [3]f32
		mouse_movement.x = (cast(f32)new_mouse_pos.x - cast(f32)last_mouse_pos.x)
		mouse_movement.y = (cast(f32)new_mouse_pos.y - cast(f32)last_mouse_pos.y)
		last_mouse_pos = new_mouse_pos

		camera_rotation += mouse_movement * cast(f32)delta_time
		camera_rotation.y = math.min(camera_rotation.y, 90)
		camera_rotation.y = math.max(camera_rotation.y, -90)
		camera_rotation_r : [3]f32 = {bdm.to_radians(camera_rotation.x), bdm.to_radians(camera_rotation.y), bdm.to_radians(camera_rotation.z)}
		
		rot : [3]f32
		rot.x = math.sin(camera_rotation_r.x) * math.cos(camera_rotation_r.y)
		rot.y = math.sin(camera_rotation_r.y) * math.cos(camera_rotation_r.x)
		rot.z = math.cos(camera_rotation_r.x) * math.cos(camera_rotation_r.y)

		ctx.camera_direction = rot
		// ctx.camera_direction = {
		// 	math.sin(camera_rotation_r.x),
		// 	math.sin(camera_rotation_r.y),
		// 	math.cos(camera_rotation_r.x) * math.cos(camera_rotation_r.y)
		// }

		// ctx.camera_direction += mouse_movement * cast(f32)delta_time
		// dir : [4]f32 = {0, 0, 1, 0} * bdm.make_euler_rotation(camera_rotation_r)
		// dir3 : [3]f32 = {(dir.x), (dir.y), dir.z}
		// ctx.camera_direction = {0, 0, -1}

		mesh.transform.rotation.x += 0.001 * cast(f32)delta_time

		// fmt.println(camera_rotation)

		for sdl.PollEvent(&event) == true {
			#partial switch event.type {
			case .QUIT:
				break engine_loop
			case .KEYDOWN:
				#partial switch event.key.keysym.sym {
					case .W:
						if key_pressed[0] {
							break
						}
						key_pressed[0] = true
						camera_velocity.z += 1
					case .A:
						if key_pressed[1] {
							break
						}
						key_pressed[1] = true
						camera_velocity.x -= 1
					case .S:
						if key_pressed[2] {
							break
						}
						key_pressed[2] = true
						camera_velocity.z -= 1
					case .D:
						if key_pressed[3] {
							break
						}
						key_pressed[3] = true
						camera_velocity.x += 1
				}
			case .KEYUP:
				#partial switch event.key.keysym.sym {
					case .W:
						key_pressed[0] = false
						camera_velocity.z += -1
					case .A:
						key_pressed[1] = false
						camera_velocity.x -= -1
					case .S:
						key_pressed[2] = false
						camera_velocity.z -= -1
					case .D:
						key_pressed[3] = false
						camera_velocity.x += -1
				}
			}
		}

		cam : [3]f32 = ctx.camera_pos
		target : [3]f32 = ctx.camera_pos + ctx.camera_direction
		forward := -bdm.normalize_vec3(cam - target)
		side := bdm.normalize_vec3(bdm.cross3(-forward, {0, 1, 0}))

		ctx.camera_pos += forward * camera_velocity.z * 0.1 * cast(f32)delta_time
		ctx.camera_pos += side * camera_velocity.x * 0.1 * cast(f32)delta_time
		// ctx.camera_pos += camera_velocity * 0.1 * cast(f32)delta_time

		vkr.render(&ctx)
	}

	fmt.println("Application Shutting Down!")
}
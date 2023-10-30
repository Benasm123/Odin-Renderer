package Application

import "core:fmt"
import "core:os"
import "core:math/rand"
import "core:math"
import "core:time"
import "core:strings"
import bdm "../math_utils"
import vkr "../vulkan_renderer"
import "../memory"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

Bullet : struct {
	using static_mesh : vkr.StaticMesh
}

Application :: struct {
    renderer: vkr.Context,

    key_pressed : [4]bool,
	camera_velocity : [3]f32,
	last_mouse_pos : [2]i32,
	mouse_down : bool,

	robot_pool : memory.ObjectPool(type_of(Bullet), 200),
	gun_pool : memory.ObjectPool(type_of(Bullet), 200),
	tommy_pool : memory.ObjectPool(type_of(Bullet), 200),
}

Init :: proc(using app: ^Application) {
    using bdm

	if vkr.init_renderer(&renderer) != .SUCCESS {
		fmt.println("Failed to initialise renderer")
		os.exit(1)
	}

	sdl.GetMouseState(&last_mouse_pos.x, &last_mouse_pos.y)

    mouse_down = false

    instance_data : []Vec3 = {{0, 0, 0}}

	for &bullet in robot_pool.objects {
		r := rand.float32() * 500
		g := rand.float32() * 500
		b := rand.float32() * 500
		bullet.meshID = vkr.create_mesh_from_file(&renderer, "Robot.obj", {0, 0, 0})
		bullet.transform.position = {r, 0, b}
		bullet.transform.scale = {1, 1, 1}
		bullet.state = .IDLE
		append(&renderer.meshes, &bullet)
	}

	for &bullet in gun_pool.objects {
		r := rand.float32() * 500
		g := rand.float32() * 5
		b := rand.float32() * 500
		bullet.meshID = vkr.create_mesh_from_file(&renderer, "Pistol.obj", {0, 0, 0})
		bullet.transform.position = {r, g, b}
		bullet.transform.scale = {10, 10, 10}
		bullet.state = .IDLE
		append(&renderer.meshes, &bullet)
	}

	for &bullet in tommy_pool.objects {
		r := rand.float32() * 500
		g := rand.float32() * 5
		b := rand.float32() * 500
		bullet.meshID = vkr.create_mesh_from_file(&renderer, "TommyGun.obj", {0, 0, 0})
		bullet.transform.position = {r, g, b}
		bullet.transform.scale = {1, 1, 1}
		bullet.state = .IDLE
		append(&renderer.meshes, &bullet)
	}
}

Run :: proc(using app: ^Application) {
    using bdm

	event: sdl.Event
	last_tick := time.now()
	defer {
		vkr.destroy_renderer(&renderer)
		sdl.DestroyWindow(renderer.window)
		sdl.Quit()
	}

	counter : f64 = 0

    engine_loop: for {
		current := time.now()
		delta_time := time.duration_milliseconds(time.diff(last_tick, current)) / 1000
		last_tick = current

		counter += delta_time
		if counter >= 1.0 {
			counter -= 1.0
			fmt.println(renderer.fps_count)
			renderer.fps_count = 0
		}


		new_mouse_pos : [2]i32
		if (mouse_down) {
			sdl.GetMouseState(&new_mouse_pos.x, &new_mouse_pos.y)
		} else {
			new_mouse_pos = last_mouse_pos
		}

		mouse_movement : [2]f32
		mouse_movement.x = (cast(f32)new_mouse_pos.x - cast(f32)last_mouse_pos.x)
		mouse_movement.y = (cast(f32)new_mouse_pos.y - cast(f32)last_mouse_pos.y)
		last_mouse_pos = new_mouse_pos


		// MARKER this should be more contained.
   	 	vkr.update_camera_input(&renderer.camera, mouse_movement)
		renderer.camera->Update(0)


		for sdl.PollEvent(&event) == true {
			#partial switch event.type {
			case .QUIT:
				break engine_loop
			case .MOUSEBUTTONDOWN:
				mouse_down = true
				sdl.GetMouseState(&last_mouse_pos.x, &last_mouse_pos.y)
			case .MOUSEBUTTONUP:
				mouse_down = false
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

		c3 : f32 = math.cos_f32(bdm.to_radians(renderer.camera.rotation.z))
		s3 : f32 = math.sin_f32(bdm.to_radians(renderer.camera.rotation.z))
		c2 : f32 = math.cos_f32(bdm.to_radians(renderer.camera.rotation.y))
		s2 : f32 = math.sin_f32(bdm.to_radians(renderer.camera.rotation.y))
		c1 : f32 = math.cos_f32(bdm.to_radians(renderer.camera.rotation.x))
		s1 : f32 = math.sin_f32(bdm.to_radians(renderer.camera.rotation.x))
		right : Vec3 = { (c1 * c3 + s1 * s2 * s3), (c2 * s3), (c1 * s2 * s3 - c3 * s1) };
		up : Vec3 = { (c3 * s1 * s2 - c1 * s3), (c2 * c3), (c1 * c3 * s2 + s1 * s3) };
		forward : Vec3 = { (c2 * s1), (-s2), (c1 * c2) };

		renderer.camera.position += -forward * camera_velocity.z * 20 * cast(f32)delta_time
		renderer.camera.position += right * camera_velocity.x * 20 * cast(f32)delta_time

		vkr.render(&renderer)
	}
}
package vulkan_renderer

// TODO -> ADD INSTANCING

import "core:fmt"
import "core:mem"
import "core:math"
import "core:time"
import vk "vendor:vulkan"
import bdm "../math_utils"
import sdl "vendor:sdl2"

MAX_FRAMES_IN_FLIGHT :: 2

when ODIN_DEBUG {
	INSTANCE_LAYERS := [?]cstring{
		"VK_LAYER_KHRONOS_validation",
		"VK_LAYER_LUNARG_monitor"
	}
} else {
	INSTANCE_LAYERS := [?]cstring{
		
	}
}

INSTANCE_EXTENSION := [?]cstring{

}

DEVICE_EXTENSIONS := [?]cstring{
	"VK_KHR_swapchain"
}

ErrorCode :: enum {
	SUCCESS,
	FAILURE
}
 
// MARKER Use this to find queue index for type
QueueFamilyType :: enum {
	GRAPHICS,
	COMPUTE 
}

Context :: struct {
	instance: vk.Instance,
  	device: vk.Device,
	physical_device: vk.PhysicalDevice,
	swapchain: vk.SwapchainKHR,
	swapchain_resources: SwapchainResources,
	swapchain_settings: SwapchainSettings,
	render_pass: vk.RenderPass,
	pipeline_layout: vk.PipelineLayout,
	descriptor_pool: vk.DescriptorPool,
	pipeline: vk.Pipeline,
	line_pipeline: vk.Pipeline,
	queue_indices: [QueueFamilyType]int,
	queues: [QueueFamilyType]vk.Queue,
	surface: vk.SurfaceKHR,
	window: ^sdl.Window,
	command_pool: vk.CommandPool,
	command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,
	
	clear_values : [3]vk.ClearValue,
	
	image_available: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight: [MAX_FRAMES_IN_FLIGHT]vk.Fence,

	scissor: vk.Rect2D,
	viewport: vk.Viewport,
	
	curr_frame: u32,
	sample_count: vk.SampleCountFlag,
	framebuffer_resized: bool,

	meshes: [dynamic]^StaticMesh,
	line_meshes: [dynamic]^StaticMesh,

	camera: Camera,
	instance_buffer : Buffer,
	fps_count : u32,
}

create_command_buffer :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
	command_pool_info : vk.CommandPoolCreateInfo
	command_pool_info.sType = .COMMAND_POOL_CREATE_INFO
	command_pool_info.flags = {.RESET_COMMAND_BUFFER}
	command_pool_info.queueFamilyIndex = cast(u32)queue_indices[.GRAPHICS]

	vk.CreateCommandPool(device, &command_pool_info, nil, &command_pool)

	allocate_info: vk.CommandBufferAllocateInfo
	allocate_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	allocate_info.commandPool = command_pool
	allocate_info.level = .PRIMARY
	allocate_info.commandBufferCount = MAX_FRAMES_IN_FLIGHT

	vk.AllocateCommandBuffers(device, &allocate_info, &command_buffers[0])

	return
}

create_semaphores_and_fences :: proc(using ctx: ^Context) {
	for i in 0..<MAX_FRAMES_IN_FLIGHT {
		semaphore_info: vk.SemaphoreCreateInfo
		semaphore_info.sType = .SEMAPHORE_CREATE_INFO

		vk.CreateSemaphore(device, &semaphore_info, nil, &image_available[i])
		vk.CreateSemaphore(device, &semaphore_info, nil, &render_finished[i])

		fence_info: vk.FenceCreateInfo
		fence_info.sType = .FENCE_CREATE_INFO
		fence_info.flags = {.SIGNALED}
		vk.CreateFence(device, &fence_info, nil, &in_flight[i])
	}
}

init_renderer :: proc(using ctx: ^Context) -> (ErrorCode) {
	sdl.Init(sdl.INIT_VIDEO)
	window = sdl.CreateWindow("Project B", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 1200, 800, sdl.WINDOW_VULKAN + sdl.WINDOW_RESIZABLE)

	sample_count = ._8 // WEAK_TODO This should be checked and set

 	if create_instance(ctx) != .SUCCESS do return .FAILURE
	if create_surface(ctx) != .SUCCESS do return .FAILURE
	if find_best_physical_device(ctx) != .SUCCESS do return .FAILURE
	if get_queue_families(ctx) != .SUCCESS do return .FAILURE
	if create_device(ctx) != .SUCCESS do return .FAILURE
	if create_swapchain(ctx) != .SUCCESS do return .FAILURE
	if create_render_pass(ctx) != .SUCCESS do return .FAILURE
	if create_framebuffers(ctx) != .SUCCESS do return .FAILURE

	scissor.extent = swapchain_resources.extent
	viewport.width = cast(f32)swapchain_resources.extent.width
	viewport.height = cast(f32)swapchain_resources.extent.height
	viewport.minDepth = 0.0
	viewport.maxDepth = 1.0

	if create_pipeline_layout(ctx) != .SUCCESS do return .FAILURE
	if create_graphics_pipeline(ctx, &pipeline, {"basic.vert.spv", "basic.frag.spv"}, {.FILL, .TRIANGLE_LIST}) != .SUCCESS do return .FAILURE
	if create_graphics_pipeline(ctx, &line_pipeline, {"basic.vert.spv", "basic.frag.spv"}, {.FILL, .LINE_STRIP}) != .SUCCESS do return .FAILURE
	if create_command_buffer(ctx) != .SUCCESS do return .FAILURE

	create_semaphores_and_fences(ctx)

	// Set Clear Values
	clear_values[0].color.float32 = [4]f32{0.1, 0.1, 0.1, 1}
	clear_values[1].depthStencil = {1.0, 0}
	clear_values[2].color.float32 = [4]f32{0.1, 0.1, 0.1, 1}

	camera = make_camera(60, viewport.width / viewport.height)

	instance_data : [1]Vec3 = {{0, 0, 0}}
	instance_buffer = create_buffer(ctx, instance_data[:], {.VERTEX_BUFFER})

	return .SUCCESS
}

render :: proc(using ctx: ^Context) {
	cmd_buffer := command_buffers[curr_frame]

	if vk.WaitForFences(device, 1, &in_flight[curr_frame], true, 0) != .SUCCESS do return
	vk.ResetFences(device, 1, &in_flight[curr_frame])

	image_index: u32
	vk.AcquireNextImageKHR(device, swapchain, 0, image_available[curr_frame], 0, &image_index)

	fps_count += 1

	begin_info: vk.CommandBufferBeginInfo
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO

	vk.ResetCommandBuffer(cmd_buffer, {})
	vk.BeginCommandBuffer(cmd_buffer, &begin_info)
	{
		// These can be constants

		render_pass_begin_info: vk.RenderPassBeginInfo
		render_pass_begin_info.sType = .RENDER_PASS_BEGIN_INFO
		render_pass_begin_info.renderPass = render_pass
		render_pass_begin_info.framebuffer = swapchain_resources.framebuffers[image_index]
		render_pass_begin_info.renderArea = scissor
		render_pass_begin_info.clearValueCount = len(clear_values)
		render_pass_begin_info.pClearValues = &clear_values[0]

		vk.CmdBeginRenderPass(cmd_buffer, &render_pass_begin_info, .INLINE)

		vk.CmdSetScissor(cmd_buffer, 0, 1, &scissor)
		vk.CmdSetViewport(cmd_buffer,0, 1, &viewport)

		vk.CmdBindPipeline(cmd_buffer, .GRAPHICS, pipeline)

        for mesh in meshes {
			render_mesh(ctx, mesh)
		}

		vk.CmdBindPipeline(cmd_buffer, .GRAPHICS, line_pipeline)

		for mesh in line_meshes {
			render_mesh(ctx, mesh)
		}

		vk.CmdEndRenderPass(cmd_buffer)
	}
	vk.EndCommandBuffer(cmd_buffer)

	wait_mask: vk.PipelineStageFlags = {.COLOR_ATTACHMENT_OUTPUT}

	submit_info: vk.SubmitInfo
	submit_info.sType = .SUBMIT_INFO
	submit_info.pWaitDstStageMask = &wait_mask
	submit_info.waitSemaphoreCount = 1
	submit_info.pWaitSemaphores = &image_available[curr_frame]
	submit_info.commandBufferCount = 1
	submit_info.pCommandBuffers = &cmd_buffer
	submit_info.signalSemaphoreCount = 1
	submit_info.pSignalSemaphores = &render_finished[curr_frame]

	vk.QueueSubmit(queues[.GRAPHICS], 1, &submit_info, in_flight[curr_frame])

	present_info: vk.PresentInfoKHR
	present_info.sType = .PRESENT_INFO_KHR
	present_info.waitSemaphoreCount = 1
	present_info.pWaitSemaphores = &render_finished[curr_frame]
	present_info.swapchainCount = 1
	present_info.pSwapchains = &swapchain
	present_info.pImageIndices = &image_index

	if vk.QueuePresentKHR(queues[.GRAPHICS], &present_info) != .SUCCESS {
		resize_destroy(ctx)
		
		create_swapchain(ctx)
		create_framebuffers(ctx)
		create_semaphores_and_fences(ctx)

		scissor.extent = swapchain_resources.extent
		viewport.width = cast(f32)swapchain_resources.extent.width
		viewport.height = cast(f32)swapchain_resources.extent.height
		viewport.minDepth = 0.0
		viewport.maxDepth = 1.0

		camera.aspect_ratio = viewport.width / viewport.height	
		update_projection_matrix(&camera)
		return
	}

	curr_frame += 1
	curr_frame %= MAX_FRAMES_IN_FLIGHT
}

render_mesh :: proc(using ctx: ^Context, static_mesh: ^StaticMesh) {
	cmd_buffer := command_buffers[curr_frame]
	mvp := bdm.identity_matrix_4x4

	scale_matrix := bdm.make_scale_matrix(static_mesh.transform.scale)
	rotation_matrix := bdm.make_euler_rotation(static_mesh.transform.rotation)
	translate_matrix := bdm.make_translation_matrix(static_mesh.transform.position)
	mvp = mvp * scale_matrix * rotation_matrix * translate_matrix

	mvp = mvp * camera.viewMatrix * camera.projectionMatrix

	vk.CmdPushConstants(cmd_buffer, pipeline_layout, {.VERTEX}, 0, size_of(mvp), &mvp)

	offset: []vk.DeviceSize = {0, 0}

	mesh := MeshTable[static_mesh.meshID]

	vb : []vk.Buffer = {mesh.vertex_buffer.buffer, instance_buffer.buffer}

	vk.CmdBindVertexBuffers(cmd_buffer, 0, cast(u32)len(vb), &vb[0], &offset[0])
	vk.CmdBindIndexBuffer(cmd_buffer, mesh.index_buffer.buffer, 0, .UINT32)
	vk.CmdDrawIndexed(cmd_buffer, mesh.triangles * 3, 1, 0, 0, 0)
}

resize_destroy :: proc(using ctx: ^Context) {
	vk.DeviceWaitIdle(device)

	for i in 0..<MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(device, image_available[i], nil)
		vk.DestroySemaphore(device, render_finished[i], nil)
		vk.DestroyFence(device, in_flight[i], nil)
	}

	for depth_image in swapchain_resources.depth_images {
		vk.FreeMemory(device, depth_image.memory, nil)
		vk.DestroyImageView(device, depth_image.image_view, nil)
		vk.DestroyImage(device, depth_image.image, nil)
	}
	delete(swapchain_resources.depth_images)
	fmt.println("    " + "Depth Resources Destroyed")
	

	for multi_image in swapchain_resources.multi_images {
		vk.FreeMemory(device, multi_image.memory, nil)
		vk.DestroyImageView(device, multi_image.image_view, nil)
		vk.DestroyImage(device, multi_image.image, nil)
	}
	delete(swapchain_resources.multi_images)
	fmt.println("    " + "MultiSample Resources Destroyed")

	for framebuffer in swapchain_resources.framebuffers {
		vk.DestroyFramebuffer(device, framebuffer, nil)
	}
	delete(swapchain_resources.framebuffers)
	fmt.println("    " + "Framebuffers Destroyed")
}

destroy_renderer :: proc(using ctx: ^Context) {
	vk.DeviceWaitIdle(device)
	fmt.println("Renderer Destroy Begin")

	vk.FreeMemory(device, instance_buffer.memory, nil)
	vk.DestroyBuffer(device, instance_buffer.buffer, nil)
	instance_buffer.data_ptr = nil

	DestroyMeshes(ctx)
	fmt.println("    " + "Meshes Destroyed")

	for i in 0..<MAX_FRAMES_IN_FLIGHT {
		vk.DestroySemaphore(device, image_available[i], nil)
		vk.DestroySemaphore(device, render_finished[i], nil)
		vk.DestroyFence(device, in_flight[i], nil)
	}
	fmt.println("    " + "Synchronization Destroyed")

	vk.DestroyCommandPool(device, command_pool, nil)
	fmt.println("    " + "Command Pool Destroyed")

	vk.DestroyPipeline(device, pipeline, nil)
	fmt.println("    " + "Graphics Pipeline Destroyed")

	vk.DestroyPipeline(device, line_pipeline, nil)
	fmt.println("    " + "Line Pipeline Destroyed")

	vk.DestroyDescriptorPool(device, descriptor_pool, nil)
	fmt.println("    " + "Descriptor Pool Destroyed")

	vk.DestroyPipelineLayout(device, pipeline_layout, nil)
	fmt.println("    " + "Pipeline Layout Destroyed")

	vk.DestroyRenderPass(device, render_pass, nil)
	fmt.println("    " + "Render Pass Destroyed")

	for image_view in swapchain_resources.image_views {
		vk.DestroyImageView(device, image_view, nil)
	}
	delete(swapchain_resources.image_views)
	fmt.println("    " + "Swapchain ImageViews Destroyed")

	for depth_image in swapchain_resources.depth_images {
		vk.FreeMemory(device, depth_image.memory, nil)
		vk.DestroyImageView(device, depth_image.image_view, nil)
		vk.DestroyImage(device, depth_image.image, nil)
	}
	delete(swapchain_resources.depth_images)
	fmt.println("    " + "Depth Resources Destroyed")
	

	for multi_image in swapchain_resources.multi_images {
		vk.FreeMemory(device, multi_image.memory, nil)
		vk.DestroyImageView(device, multi_image.image_view, nil)
		vk.DestroyImage(device, multi_image.image, nil)
	}
	delete(swapchain_resources.multi_images)
	fmt.println("    " + "MultiSample Resources Destroyed")

	for framebuffer in swapchain_resources.framebuffers {
		vk.DestroyFramebuffer(device, framebuffer, nil)
	}
	delete(swapchain_resources.framebuffers)
	fmt.println("    " + "Framebuffers Destroyed")

	vk.DestroySwapchainKHR(device, swapchain, nil)
	delete(swapchain_resources.images)
	fmt.println("    " + "Swapchain Destroyed")

	vk.DestroyDevice(device, nil)
	fmt.println("    " + "Device Destroyed")

	vk.DestroySurfaceKHR(instance, surface, nil)
	fmt.println("    " + "Surface Destroyed")

	vk.DestroyInstance(instance, nil)
	fmt.println("    " + "Instance Destroyed")

	fmt.println("Renderer Destroyed")
}
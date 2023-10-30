package vulkan_renderer

import vk "vendor:vulkan"
import bdm "../math_utils"

Buffer :: struct {
	buffer: vk.Buffer,
	memory: vk.DeviceMemory,
	length: int,
	size: vk.DeviceSize,
	data_ptr: rawptr
}

Image :: struct {
	image: vk.Image,
	memory: vk.DeviceMemory,
	image_view: vk.ImageView
}

SwapchainResources :: struct {
	images: []vk.Image,
	image_views: []vk.ImageView,
	framebuffers: []vk.Framebuffer,
	depth_images: []Image,
	multi_images: []Image,
	extent: vk.Extent2D, // MARKER ---- Use this when we hit a possible resize, and verify we actually need to recreate the swapchain!
}

SwapchainSettings :: struct {
	format: vk.SurfaceFormatKHR,
	present_mode: vk.PresentModeKHR,
	image_count: u32,
}
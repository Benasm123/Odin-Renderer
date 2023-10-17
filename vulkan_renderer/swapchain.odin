package vulkan_renderer

import "core:fmt"
import vk "vendor:vulkan"

@private
find_swapchain_settings :: proc(using ctx: ^Context) { 
    surface_capabilities: vk.SurfaceCapabilitiesKHR
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities)

    surface_format_count: u32
    vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &surface_format_count, nil)
    available_surface_formats := make([]vk.SurfaceFormatKHR, surface_format_count)
    defer delete(available_surface_formats)
    vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &surface_format_count, raw_data(available_surface_formats))

    swapchain_settings.format = available_surface_formats[0]
    for format in available_surface_formats do if format.format == .B8G8R8A8_UNORM {swapchain_settings.format = format}

    swapchain_settings.image_count = surface_capabilities.minImageCount + 1

    surface_present_modes_count: u32
    vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &surface_present_modes_count, nil)
    available_present_modes := make([]vk.PresentModeKHR, surface_present_modes_count)
    defer delete(available_present_modes)
    vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &surface_present_modes_count, &available_present_modes[0])

    swapchain_settings.present_mode = available_present_modes[0]
    for present_mode in available_present_modes do if present_mode == .MAILBOX {swapchain_settings.present_mode = present_mode}

    fmt.println("Swapchain Format:", swapchain_settings.format)
    fmt.println("Swapchain Image Count:", swapchain_settings.image_count)
    fmt.println("Swapchain Present Mode:", swapchain_settings.present_mode)
}

create_swapchain :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    surface_capabilities: vk.SurfaceCapabilitiesKHR
    vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities)

    find_swapchain_settings(ctx)

    swapchain_resources.extent = surface_capabilities.currentExtent

    old_swapchain: vk.SwapchainKHR = swapchain;

    swapchain_info: vk.SwapchainCreateInfoKHR
    swapchain_info.sType = .SWAPCHAIN_CREATE_INFO_KHR
    swapchain_info.clipped = true
    swapchain_info.compositeAlpha = {.OPAQUE}
    swapchain_info.minImageCount = swapchain_settings.image_count
    swapchain_info.imageFormat = swapchain_settings.format.format
    swapchain_info.imageExtent = swapchain_resources.extent
    swapchain_info.imageArrayLayers = 1
    swapchain_info.imageUsage = {.COLOR_ATTACHMENT}
    swapchain_info.imageSharingMode = .EXCLUSIVE
    swapchain_info.preTransform = surface_capabilities.currentTransform
    swapchain_info.presentMode = swapchain_settings.present_mode
    swapchain_info.oldSwapchain = old_swapchain
    swapchain_info.surface = surface

    if vk.CreateSwapchainKHR(device, &swapchain_info, nil, &swapchain) != .SUCCESS { return .FAILURE}

    for image_view in swapchain_resources.image_views {
        vk.DestroyImageView(device, image_view, nil)
    }
    delete(swapchain_resources.image_views)
    
    vk.DestroySwapchainKHR(device, old_swapchain, nil)

    delete(swapchain_resources.images)

    swapchain_image_count: u32
    vk.GetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, nil)
    swapchain_settings.image_count = swapchain_image_count
    swapchain_resources.images = make([]vk.Image, swapchain_image_count)
    vk.GetSwapchainImagesKHR(device, swapchain, &swapchain_image_count, raw_data(swapchain_resources.images))

    swapchain_resources.image_views = make([]vk.ImageView, swapchain_image_count)
    
    for image, index in swapchain_resources.images {
        imageview_info: vk.ImageViewCreateInfo
        imageview_info.sType = .IMAGE_VIEW_CREATE_INFO
        imageview_info.image = image
        imageview_info.viewType = .D2
        imageview_info.format = swapchain_settings.format.format
        imageview_info.components.r = .IDENTITY
        imageview_info.components.g = .IDENTITY
        imageview_info.components.b = .IDENTITY
        imageview_info.components.a = .IDENTITY
        imageview_info.subresourceRange.aspectMask = {.COLOR}
        imageview_info.subresourceRange.baseMipLevel = 0
        imageview_info.subresourceRange.levelCount = 1
        imageview_info.subresourceRange.baseArrayLayer = 0
        imageview_info.subresourceRange.layerCount = 1

        vk.CreateImageView(device, &imageview_info, nil, &swapchain_resources.image_views[index])
    }

    return
}

create_framebuffers :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    // FRAMEBUFFER
    swapchain_resources.framebuffers = make([]vk.Framebuffer, swapchain_settings.image_count)
    swapchain_resources.depth_images = make([]Image, swapchain_settings.image_count)
    swapchain_resources.multi_images = make([]Image, swapchain_settings.image_count)
    for i in 0..<swapchain_settings.image_count {
        // DEPTH
        depth_info: vk.ImageCreateInfo
        depth_info.sType = .IMAGE_CREATE_INFO
        depth_info.imageType = .D2
        depth_info.extent = {swapchain_resources.extent.width, swapchain_resources.extent.height, 1}
        depth_info.mipLevels = 1
        depth_info.arrayLayers = 1
        depth_info.format = .D24_UNORM_S8_UINT
        depth_info.tiling = .OPTIMAL
        depth_info.initialLayout = .UNDEFINED
        depth_info.usage = {.DEPTH_STENCIL_ATTACHMENT}
        depth_info.samples = {sample_count}

        vk.CreateImage(device, &depth_info, nil, &swapchain_resources.depth_images[i].image)

        depth_req : vk.MemoryRequirements
        vk.GetImageMemoryRequirements(device, swapchain_resources.depth_images[i].image, &depth_req)

        depth_allocate_info : vk.MemoryAllocateInfo
        depth_allocate_info.sType = .MEMORY_ALLOCATE_INFO
        depth_allocate_info.allocationSize = depth_req.size
        depth_allocate_info.memoryTypeIndex = get_memory_from_properties(ctx, {.DEVICE_LOCAL})

        vk.AllocateMemory(device, &depth_allocate_info, nil, &swapchain_resources.depth_images[i].memory)
        vk.BindImageMemory(device, swapchain_resources.depth_images[i].image, swapchain_resources.depth_images[i].memory, 0);

        view_range: vk.ImageSubresourceRange
        view_range.aspectMask = {.DEPTH, .STENCIL}
        view_range.baseMipLevel = 0
        view_range.levelCount = 1
        view_range.baseArrayLayer = 0
        view_range.layerCount = 1

        depth_view_info: vk.ImageViewCreateInfo
        depth_view_info.sType = .IMAGE_VIEW_CREATE_INFO
        depth_view_info.image = swapchain_resources.depth_images[i].image
        depth_view_info.format = .D24_UNORM_S8_UINT
        depth_view_info.subresourceRange = view_range
        depth_view_info.viewType = .D2

        vk.CreateImageView(device, &depth_view_info, nil, &swapchain_resources.depth_images[i].image_view)

        // MULTI SAMPLE
        multi_info: vk.ImageCreateInfo
        multi_info.sType = .IMAGE_CREATE_INFO
        multi_info.imageType = .D2
        multi_info.extent = {swapchain_resources.extent.width, swapchain_resources.extent.height, 1}
        multi_info.mipLevels = 1
        multi_info.arrayLayers = 1
        multi_info.format = swapchain_settings.format.format
        multi_info.tiling = .OPTIMAL
        multi_info.initialLayout = .UNDEFINED
        multi_info.usage = {.COLOR_ATTACHMENT}
        multi_info.samples = {sample_count}

        vk.CreateImage(device, &multi_info, nil, &swapchain_resources.multi_images[i].image)

        multi_req : vk.MemoryRequirements
        vk.GetImageMemoryRequirements(device, swapchain_resources.multi_images[i].image, &multi_req)

        multi_allocate_info : vk.MemoryAllocateInfo
        multi_allocate_info.sType = .MEMORY_ALLOCATE_INFO
        multi_allocate_info.allocationSize = multi_req.size
        multi_allocate_info.memoryTypeIndex = get_memory_from_properties(ctx, {.DEVICE_LOCAL})

        vk.AllocateMemory(device, &multi_allocate_info, nil, &swapchain_resources.multi_images[i].memory)
        vk.BindImageMemory(device, swapchain_resources.multi_images[i].image, swapchain_resources.multi_images[i].memory, 0);

        view_range.aspectMask = {.COLOR}
        view_range.baseMipLevel = 0
        view_range.levelCount = 1
        view_range.baseArrayLayer = 0
        view_range.layerCount = 1

        multi_view_info: vk.ImageViewCreateInfo
        multi_view_info.sType = .IMAGE_VIEW_CREATE_INFO
        multi_view_info.image = swapchain_resources.multi_images[i].image
        multi_view_info.format = swapchain_settings.format.format
        multi_view_info.subresourceRange = view_range
        multi_view_info.viewType = .D2

        vk.CreateImageView(device, &multi_view_info, nil, &swapchain_resources.multi_images[i].image_view)

        attachments := []vk.ImageView{
            swapchain_resources.multi_images[i].image_view,
            swapchain_resources.depth_images[i].image_view,
            swapchain_resources.image_views[i]
        }

        // FRAMEBUFFER
        framebuffer_info: vk.FramebufferCreateInfo
        framebuffer_info.sType = .FRAMEBUFFER_CREATE_INFO
        framebuffer_info.attachmentCount = cast(u32)len(attachments)
        framebuffer_info.pAttachments = &attachments[0]
        framebuffer_info.width = swapchain_resources.extent.width
        framebuffer_info.height = swapchain_resources.extent.height
        framebuffer_info.layers = 1
        framebuffer_info.renderPass = render_pass

        vk.CreateFramebuffer(device, &framebuffer_info, nil, &swapchain_resources.framebuffers[i])
    }

    return
}

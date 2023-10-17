package vulkan_renderer

import "core:fmt"
import vk "vendor:vulkan"

create_render_pass :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    attachment_descriptions: [3]vk.AttachmentDescription
    
    // MultiSampled Attachment
    attachment_descriptions[0].format = swapchain_settings.format.format
    attachment_descriptions[0].loadOp = .CLEAR
    attachment_descriptions[0].storeOp = .STORE
    attachment_descriptions[0].initialLayout = .UNDEFINED
    attachment_descriptions[0].finalLayout = .COLOR_ATTACHMENT_OPTIMAL
    attachment_descriptions[0].samples = { sample_count }                                                                                                                       

    // Depth Attachment
    attachment_descriptions[1].format = .D24_UNORM_S8_UINT // TODO Set this somewhere and get.
    attachment_descriptions[1].loadOp = .CLEAR
    attachment_descriptions[1].storeOp = .DONT_CARE
    attachment_descriptions[1].stencilLoadOp = .DONT_CARE
    attachment_descriptions[1].stencilStoreOp = .DONT_CARE
    attachment_descriptions[1].initialLayout = .UNDEFINED
    attachment_descriptions[1].finalLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
    attachment_descriptions[1].samples = { sample_count }    

    // Output Attachment
    attachment_descriptions[2].format = swapchain_settings.format.format
    attachment_descriptions[2].loadOp = .CLEAR
    attachment_descriptions[2].storeOp = .STORE
    attachment_descriptions[2].initialLayout = .UNDEFINED
    attachment_descriptions[2].finalLayout = .PRESENT_SRC_KHR
    attachment_descriptions[2].samples = { ._1 }

    // Dependencies
    dependencies: [1]vk.SubpassDependency
    dependencies[0].srcStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS}
    dependencies[0].srcAccessMask = {}
    dependencies[0].dstStageMask = {.COLOR_ATTACHMENT_OUTPUT, .EARLY_FRAGMENT_TESTS}
    dependencies[0].dstAccessMask = {.COLOR_ATTACHMENT_WRITE, .DEPTH_STENCIL_ATTACHMENT_WRITE}
    dependencies[0].srcSubpass = vk.SUBPASS_EXTERNAL
    dependencies[0].dstSubpass = 0

    // References
    references: [3]vk.AttachmentReference

    // Multisample Ref
    references[0].attachment = 0
    references[0].layout = .COLOR_ATTACHMENT_OPTIMAL

    // Depth Ref
    references[1].attachment = 1
    references[1].layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL

    // Output Ref
    references[2].attachment = 2
    references[2].layout = .COLOR_ATTACHMENT_OPTIMAL

    subpass_descriptions: [1]vk.SubpassDescription
    subpass_descriptions[0].colorAttachmentCount = 1
    subpass_descriptions[0].pColorAttachments = &references[0]
    subpass_descriptions[0].inputAttachmentCount = 0
    subpass_descriptions[0].pInputAttachments = nil
    subpass_descriptions[0].pDepthStencilAttachment = &references[1]
    subpass_descriptions[0].pPreserveAttachments = nil
    subpass_descriptions[0].pResolveAttachments = &references[2]
    subpass_descriptions[0].pipelineBindPoint = .GRAPHICS

    // Renderpass Finally
    render_pass_info: vk.RenderPassCreateInfo
    render_pass_info.sType = .RENDER_PASS_CREATE_INFO
    render_pass_info.attachmentCount = len(attachment_descriptions)
    render_pass_info.pAttachments = &attachment_descriptions[0]
    render_pass_info.dependencyCount = len(dependencies)
    render_pass_info.pDependencies = &dependencies[0]
    render_pass_info.subpassCount = len(subpass_descriptions)
    render_pass_info.pSubpasses = &subpass_descriptions[0]

    res := vk.CreateRenderPass(device, &render_pass_info, nil, &render_pass)
    if res != .SUCCESS do return .FAILURE

    return
}
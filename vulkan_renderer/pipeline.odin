package vulkan_renderer

import "core:fmt"
import vk "vendor:vulkan"

create_pipeline_layout :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    // TODO Descriptor pools might want to be moved out into their own thing, probably want more control.
    // TODO But i guess im keeping the pool in the context and can be accessed anywhere anyway?
    // Descriptor Set Pool
    pool_sizes: [1]vk.DescriptorPoolSize
    pool_sizes[0].descriptorCount = 14 // TODO This is a random number, not sure what it should be.
    pool_sizes[0].type = .UNIFORM_BUFFER

    descriptor_pool_info: vk.DescriptorPoolCreateInfo
    descriptor_pool_info.sType = .DESCRIPTOR_POOL_CREATE_INFO
    descriptor_pool_info.poolSizeCount = len(pool_sizes)
    descriptor_pool_info.pPoolSizes = &pool_sizes[0]
    descriptor_pool_info.maxSets = 14 // TODO this is also random, figure out what it needs to be.

    vk.CreateDescriptorPool(device, &descriptor_pool_info, nil, &descriptor_pool)

    push_constant_ranges: [1]vk.PushConstantRange
    push_constant_ranges[0].stageFlags = {.VERTEX}
    push_constant_ranges[0].size = size_of(PushConstant)
    push_constant_ranges[0].offset = 0

    pipeline_layout_info: vk.PipelineLayoutCreateInfo
    pipeline_layout_info.sType = .PIPELINE_LAYOUT_CREATE_INFO
    pipeline_layout_info.setLayoutCount = 0
    pipeline_layout_info.pSetLayouts = nil
    pipeline_layout_info.pushConstantRangeCount = len(push_constant_ranges)
    pipeline_layout_info.pPushConstantRanges = &push_constant_ranges[0]

    res := vk.CreatePipelineLayout(device, &pipeline_layout_info, nil, &pipeline_layout)
    if res != .SUCCESS do return .FAILURE

    return
}

PipelineSettings :: struct {
    fill_mode : vk.PolygonMode,
    topology : vk.PrimitiveTopology
}

create_graphics_pipeline :: proc(using ctx: ^Context, pipeline_ptr: ^vk.Pipeline, shaders: []string, settings: PipelineSettings) -> (err: ErrorCode = .SUCCESS) {
    fmt.println(shaders)
    // SHADERS
    shader_modules := make([]vk.ShaderModule, len(shaders))

    for shader, index in shaders {
        shader_code, result := read_spriv(shaders[index])
        if (result != .SUCCESS) {
            return .FAILURE
        }
        defer delete(shader_code, context.allocator)

        shader_module_info : vk.ShaderModuleCreateInfo
        shader_module_info.sType = .SHADER_MODULE_CREATE_INFO
        shader_module_info.codeSize = len(shader_code)
        shader_module_info.pCode = cast(^u32)raw_data(shader_code)

        vk.CreateShaderModule(device, &shader_module_info, nil, &shader_modules[index])
    }

    defer {
        for shader_module in shader_modules {
            vk.DestroyShaderModule(device, shader_module, nil)
        }
        delete(shader_modules)
    }

    shader_stages: [2]vk.PipelineShaderStageCreateInfo
    
    shader_stages[0].stage = {.VERTEX}
    shader_stages[0].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
    shader_stages[0].module = shader_modules[0]
    shader_stages[0].pName = "main"

    shader_stages[1].stage = {.FRAGMENT}
    shader_stages[1].sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
    shader_stages[1].module = shader_modules[1]
    shader_stages[1].pName = "main"


    // VERTEX BINDING
    vertex_binding: vk.VertexInputBindingDescription
    vertex_binding.binding = 0
    vertex_binding.stride = size_of(Vertex)
    vertex_binding.inputRate = .VERTEX

    vertex_inputs: [3]vk.VertexInputAttributeDescription
    vertex_inputs[0].location = 0
    vertex_inputs[0].binding = 0
    vertex_inputs[0].format = .R32G32B32_SFLOAT
    vertex_inputs[0].offset = cast(u32)offset_of(Vertex, pos)

    vertex_inputs[1].location = 1
    vertex_inputs[1].binding = 0
    vertex_inputs[1].format = .R32G32B32_SFLOAT
    vertex_inputs[1].offset = cast(u32)offset_of(Vertex, normal)

    vertex_inputs[2].location = 2
    vertex_inputs[2].binding = 0
    vertex_inputs[2].format = .R32G32B32_SFLOAT
    vertex_inputs[2].offset = cast(u32)offset_of(Vertex, texture)

    vertex_input_info: vk.PipelineVertexInputStateCreateInfo
    vertex_input_info.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
    vertex_input_info.vertexBindingDescriptionCount = 1
    vertex_input_info.pVertexBindingDescriptions = &vertex_binding
    vertex_input_info.vertexAttributeDescriptionCount = len(vertex_inputs)
    vertex_input_info.pVertexAttributeDescriptions = &vertex_inputs[0]


    // VERTEX INPUT ASSEMBLY
    vertex_input_assembly_info: vk.PipelineInputAssemblyStateCreateInfo
    vertex_input_assembly_info.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
    vertex_input_assembly_info.topology = settings.topology
    vertex_input_assembly_info.primitiveRestartEnable = false


    // TESSELATION
    tesselation_info: vk.PipelineTessellationStateCreateInfo
    tesselation_info.patchControlPoints = 0

    
    // VIEWPORTS //

    viewport_info: vk.PipelineViewportStateCreateInfo
    viewport_info.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
    viewport_info.viewportCount = 1
    viewport_info.pViewports = &viewport
    viewport_info.scissorCount = 1
    viewport_info.pScissors = &scissor


    // RASTERISATION
    rasterization_info: vk.PipelineRasterizationStateCreateInfo
    rasterization_info.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
    rasterization_info.depthClampEnable = false
    rasterization_info.rasterizerDiscardEnable = false
    rasterization_info.polygonMode = settings.fill_mode
    rasterization_info.cullMode = {.BACK}
    rasterization_info.frontFace = .COUNTER_CLOCKWISE
    rasterization_info.depthBiasEnable = false
    rasterization_info.depthBiasConstantFactor = 0.0
    rasterization_info.depthBiasClamp = 0.0
    rasterization_info.depthBiasSlopeFactor = 0.0
    rasterization_info.lineWidth = 1.0


    // MULTISAMPLE
    multisample_info: vk.PipelineMultisampleStateCreateInfo
    multisample_info.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
    multisample_info.rasterizationSamples = {sample_count}
    multisample_info.sampleShadingEnable = false
    multisample_info.minSampleShading = 1.0
    multisample_info.pSampleMask = nil
    multisample_info.alphaToCoverageEnable = false
    multisample_info.alphaToOneEnable = false


    // DEPTH STENCIL
    depth_stencil_info: vk.PipelineDepthStencilStateCreateInfo
    depth_stencil_info.sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO
    depth_stencil_info.depthTestEnable = true
    depth_stencil_info.depthWriteEnable = true
    depth_stencil_info.depthCompareOp = .LESS
    depth_stencil_info.depthBoundsTestEnable = false
    depth_stencil_info.stencilTestEnable = false
    depth_stencil_info.front = vk.StencilOpState{}
    depth_stencil_info.back = vk.StencilOpState{}
    depth_stencil_info.minDepthBounds = 0.0
    depth_stencil_info.maxDepthBounds = 1.0


    // COLOUR BLEND
    colour_blend_attachments: [1]vk.PipelineColorBlendAttachmentState
    colour_blend_attachments[0].blendEnable = false
    colour_blend_attachments[0].srcColorBlendFactor = .SRC_COLOR
    colour_blend_attachments[0].dstColorBlendFactor = .ONE_MINUS_DST_COLOR
    colour_blend_attachments[0].colorBlendOp = .ADD
    colour_blend_attachments[0].srcAlphaBlendFactor = .SRC_ALPHA
    colour_blend_attachments[0].dstAlphaBlendFactor = .ONE_MINUS_DST_COLOR
    colour_blend_attachments[0].alphaBlendOp = .ADD
    colour_blend_attachments[0].colorWriteMask = {.R, .G, .B, .A}

    colour_blend_info: vk.PipelineColorBlendStateCreateInfo
    colour_blend_info.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
    colour_blend_info.logicOpEnable = false
    colour_blend_info.logicOp = .AND
    colour_blend_info.attachmentCount = 1
    colour_blend_info.pAttachments = &colour_blend_attachments[0]
    colour_blend_info.blendConstants = {0.0, 0.0, 0.0, 0.0}


    // DYNAMIC STATES
    dynamic_states := []vk.DynamicState{.SCISSOR, .VIEWPORT}
    dynamic_info: vk.PipelineDynamicStateCreateInfo
    dynamic_info.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
    dynamic_info.dynamicStateCount = cast(u32)len(dynamic_states)
    dynamic_info.pDynamicStates = &dynamic_states[0]


    // PIPELINE CREATION
    pipeline_info: vk.GraphicsPipelineCreateInfo
    pipeline_info.sType = .GRAPHICS_PIPELINE_CREATE_INFO
    pipeline_info.stageCount = len(shader_stages)
    pipeline_info.pStages = &shader_stages[0]
    pipeline_info.pVertexInputState = &vertex_input_info
    pipeline_info.pInputAssemblyState = &vertex_input_assembly_info
    pipeline_info.pTessellationState = &tesselation_info
    pipeline_info.pViewportState = &viewport_info
    pipeline_info.pRasterizationState = &rasterization_info
    pipeline_info.pMultisampleState = &multisample_info
    pipeline_info.pDepthStencilState = &depth_stencil_info
    pipeline_info.pColorBlendState = &colour_blend_info
    pipeline_info.pDynamicState = &dynamic_info
    pipeline_info.layout = pipeline_layout
    pipeline_info.renderPass = render_pass
    pipeline_info.subpass = 0
    pipeline_info.basePipelineIndex = 0
    pipeline_info.basePipelineHandle = vk.Pipeline{}

    vk.CreateGraphicsPipelines(device, 0, 1, &pipeline_info, nil, pipeline_ptr)

    return 
}
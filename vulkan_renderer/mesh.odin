package vulkan_renderer

import "core:fmt"
import "core:mem"
import vk "vendor:vulkan"
import bdm "../math_utils"

Vec3 :: [3]f32

Vertex :: struct {
	pos: Vec3,
	normal: Vec3,
	texture: Vec3
}

Transform :: struct {
	position: Vec3,
	rotation: Vec3,
	scale: Vec3
}

Mesh :: struct {
	push_constant: PushConstant,
	transform: Transform,
    
	vertex_data: []Vertex,
	vertex_buffer: Buffer,
	index_data: []u32,
	index_buffer: Buffer,
}

PushConstant :: struct {
	mvp: matrix[4, 4]f32
}

create_indexed_mesh :: proc(using ctx: ^Context, mesh: ^Mesh) {
	vertex_size := cast(vk.DeviceSize)(len(mesh.vertex_data) * size_of(Vertex));

	vertex_buffer_info: vk.BufferCreateInfo
	vertex_buffer_info.sType = .BUFFER_CREATE_INFO
	vertex_buffer_info.size = vertex_size
	vertex_buffer_info.usage = {.VERTEX_BUFFER}

	vk.CreateBuffer(device, &vertex_buffer_info, nil, &mesh.vertex_buffer.buffer)
	vertex_buffer_requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device, mesh.vertex_buffer.buffer, &vertex_buffer_requirements)

	vertex_memory_allocate_info: vk.MemoryAllocateInfo
	vertex_memory_allocate_info.sType = .MEMORY_ALLOCATE_INFO
	vertex_memory_allocate_info.allocationSize = vertex_buffer_requirements.size
	vertex_memory_allocate_info.memoryTypeIndex = get_memory_from_properties(ctx, {.HOST_VISIBLE, .HOST_COHERENT})

	vk.AllocateMemory(device, &vertex_memory_allocate_info, nil, &mesh.vertex_buffer.memory)

	vk.BindBufferMemory(device, mesh.vertex_buffer.buffer, mesh.vertex_buffer.memory, 0)

	vk.MapMemory(device, mesh.vertex_buffer.memory, 0, cast(vk.DeviceSize)vk.WHOLE_SIZE, {}, &mesh.vertex_buffer.data_ptr)

	mem.copy(mesh.vertex_buffer.data_ptr, cast(rawptr)&mesh.vertex_data[0], cast(int)vertex_size)

	// INDEX
	index_size := cast(vk.DeviceSize)(len(mesh.index_data) * size_of(u32));

	index_buffer_info: vk.BufferCreateInfo
	index_buffer_info.sType = .BUFFER_CREATE_INFO
	index_buffer_info.size = index_size
	index_buffer_info.usage = {.INDEX_BUFFER}

	vk.CreateBuffer(device, &index_buffer_info, nil, &mesh.index_buffer.buffer)
	index_buffer_requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device, mesh.index_buffer.buffer, &index_buffer_requirements)

	index_memory_allocate_info: vk.MemoryAllocateInfo
	index_memory_allocate_info.sType = .MEMORY_ALLOCATE_INFO
	index_memory_allocate_info.allocationSize = index_buffer_requirements.size
	index_memory_allocate_info.memoryTypeIndex = get_memory_from_properties(ctx, {.HOST_VISIBLE, .HOST_COHERENT})

	vk.AllocateMemory(device, &index_memory_allocate_info, nil, &mesh.index_buffer.memory)

	vk.BindBufferMemory(device, mesh.index_buffer.buffer, mesh.index_buffer.memory, 0)

	vk.MapMemory(device, mesh.index_buffer.memory, 0, cast(vk.DeviceSize)vk.WHOLE_SIZE, {}, &mesh.index_buffer.data_ptr)

	mem.copy(mesh.index_buffer.data_ptr, cast(rawptr)&mesh.index_data[0], cast(int)index_size)
}

destroy_indexed_mesh :: proc(using ctx: ^Context, mesh : ^Mesh) {
	vk.DeviceWaitIdle(device)

    delete(mesh.vertex_data)
    delete(mesh.index_data)

    vk.FreeMemory(device, mesh.vertex_buffer.memory, nil)
    vk.DestroyBuffer(device, mesh.vertex_buffer.buffer, nil)

    vk.FreeMemory(device, mesh.index_buffer.memory, nil)
    vk.DestroyBuffer(device, mesh.index_buffer.buffer, nil)

    mesh.vertex_buffer.data_ptr = nil
    mesh.index_buffer.data_ptr = nil
}

create_cube_mesh :: proc(using ctx: ^Context, colour: Vec3) -> (mesh: ^Mesh) {
	mesh = new(Mesh)

	mesh.transform.scale = {1, 1, 1}

	mesh.push_constant.mvp = bdm.identity_matrix_4x4

	mesh.vertex_data = make([]Vertex, 4)
	mesh.vertex_data[0] = {
		{0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh.vertex_data[1] = 	{
		{-0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh.vertex_data[2] = 	{
		{0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh.vertex_data[3] = 	{
		{-0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}

	mesh.index_data = make([]u32, 4)
	mesh.index_data[0] = 0
	mesh.index_data[1] = 2
	mesh.index_data[2] = 1
	mesh.index_data[3] = 3

	create_indexed_mesh(ctx, mesh)

	return
}

create_line_rect :: proc(using ctx: ^Context, colour: Vec3) -> (mesh: ^Mesh) {
	mesh = new(Mesh)
	mesh.transform.scale = {1, 1, 1}

	mesh.push_constant.mvp = bdm.identity_matrix_4x4

	mesh.vertex_data = make([]Vertex, 4)
	mesh.vertex_data[0] = {
		{0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh.vertex_data[1] = 	{
		{-0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh.vertex_data[2] = 	{
		{0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh.vertex_data[3] = 	{
		{-0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}

	mesh.index_data = make([]u32, 5)
	mesh.index_data[0] = 0
	mesh.index_data[1] = 1
	mesh.index_data[2] = 3
	mesh.index_data[3] = 2
	mesh.index_data[4] = 0

	create_indexed_mesh(ctx, mesh)

	return
}
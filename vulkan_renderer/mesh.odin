package vulkan_renderer

import "core:fmt"
import "core:mem"
import "core:hash"
import vk "vendor:vulkan"
import bdm "../math_utils"

// TODO make a mesh tracker, if we load a mesh we need to add it to some table, and we can load different objects using the same data to save ram.

MeshID :: u32
MeshTable := make(map[MeshID]^IndexedMesh)

Vec3 :: [3]f32
Vec2 :: [2]f32

CoreMeshIDs :: enum {
	CUBE = 00000001,
}

Vertex :: struct {
	pos: Vec3,
	normal: Vec3,
	texture: Vec3
}

Index :: u32

Mesh :: struct {
	push_constant: PushConstant,
    
	vertex_data: []Vertex,
	vertex_buffer: Buffer,
	index_data: []u32,
	index_buffer: Buffer,

	instance_data: []Vec3,
	instance_buffer : Buffer,
}

IndexedMesh :: struct {
	vertex_buffer : Buffer,
	index_buffer : Buffer,

	triangles : u32,
}

IndexedMeshData :: struct {
	vertex_data : []Vertex,
	index_data : []Index,
}

IndexedMeshWithData :: struct {
	using mesh : IndexedMesh,
	using data : IndexedMeshData,
}

InstancedIndexedMesh :: struct {
	using mesh : IndexedMesh,

	instance_buffer : Buffer,

	instances : u32,
}

// InstancedIndexedMeshWithData :: struct {
// 	using mesh : IndexedMeshWithData,

// 	instance_data : []Vec3,
// 	instance_buffer : Buffer,

// 	instances : u32,
// }

PushConstant :: struct {
	mvp: matrix[4, 4]f32
}

MakeIndexedMesh :: proc(using renderer: ^Context, mesh_data : IndexedMeshData) -> (mesh: ^IndexedMesh) {
	mesh = new(IndexedMesh)
	mesh.vertex_buffer = create_buffer(renderer, mesh_data.vertex_data, {.VERTEX_BUFFER})
	mesh.index_buffer = create_buffer(renderer, mesh_data.index_data, {.INDEX_BUFFER})
	return 
}

create_indexed_mesh :: proc(using ctx: ^Context, mesh: ^Mesh) {
	// VERTEX	
	mesh.vertex_buffer = create_buffer(ctx, mesh.vertex_data, {.VERTEX_BUFFER})

	// INDEX
	mesh.index_buffer = create_buffer(ctx, mesh.index_data, {.INDEX_BUFFER})

	// INSTANCE
	mesh.instance_buffer = create_buffer(ctx, mesh.instance_data, {.VERTEX_BUFFER})
}

create_buffer :: proc(using ctx: ^Context, data : []$T, usage : vk.BufferUsageFlags) -> (buffer : Buffer) {
	size := cast(vk.DeviceSize)(len(data) * size_of(T));

	buffer_info: vk.BufferCreateInfo
	buffer_info.sType = .BUFFER_CREATE_INFO
	buffer_info.size = size
	buffer_info.usage = usage

	vk.CreateBuffer(device, &buffer_info, nil, &buffer.buffer)
	buffer_requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(device, buffer.buffer, &buffer_requirements)

	memory_allocate_info: vk.MemoryAllocateInfo
	memory_allocate_info.sType = .MEMORY_ALLOCATE_INFO
	memory_allocate_info.allocationSize = buffer_requirements.size
	memory_allocate_info.memoryTypeIndex = get_memory_from_properties(ctx, {.HOST_VISIBLE, .HOST_COHERENT})

	vk.AllocateMemory(device, &memory_allocate_info, nil, &buffer.memory)

	vk.BindBufferMemory(device, buffer.buffer, buffer.memory, 0)

	vk.MapMemory(device, buffer.memory, 0, cast(vk.DeviceSize)vk.WHOLE_SIZE, {}, &buffer.data_ptr)

	mem.copy(buffer.data_ptr, cast(rawptr)&data[0], cast(int)size)
	return 
}

destroy_indexed_mesh :: proc(using ctx: ^Context, mesh : ^IndexedMesh) {
	vk.DeviceWaitIdle(device)

    vk.FreeMemory(device, mesh.vertex_buffer.memory, nil)
    vk.DestroyBuffer(device, mesh.vertex_buffer.buffer, nil)

    vk.FreeMemory(device, mesh.index_buffer.memory, nil)
    vk.DestroyBuffer(device, mesh.index_buffer.buffer, nil)

    mesh.vertex_buffer.data_ptr = nil
    mesh.index_buffer.data_ptr = nil
}

create_cube_mesh :: proc(using ctx: ^Context, colour: Vec3, instance_data: []Vec3) -> (meshID: MeshID) {
	ok := cast(u32)CoreMeshIDs.CUBE in MeshTable
	if ok do return cast(u32)CoreMeshIDs.CUBE

	mesh := new(IndexedMesh)
	mesh_data : IndexedMeshData

	mesh_data.vertex_data = make([]Vertex, 4)
	defer delete(mesh_data.vertex_data)
	mesh_data.vertex_data[0] = {
		{0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh_data.vertex_data[1] = 	{
		{-0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh_data.vertex_data[2] = 	{
		{0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh_data.vertex_data[3] = 	{
		{-0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}

	mesh_data.index_data = make([]u32, 4)
	defer delete(mesh_data.index_data)
	mesh_data.index_data[0] = 0
	mesh_data.index_data[1] = 2
	mesh_data.index_data[2] = 1
	mesh_data.index_data[3] = 3

	mesh = MakeIndexedMesh(ctx, mesh_data)

	return
}

create_line_rect :: proc(using ctx: ^Context, colour: Vec3) -> (meshID: MeshID) {
	mesh := new(IndexedMesh)
	mesh_data : IndexedMeshData

	mesh_data.vertex_data = make([]Vertex, 4)
	defer delete(mesh_data.vertex_data)
	mesh_data.vertex_data[0] = {
		{0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh_data.vertex_data[1] = {
		{-0.5, -0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh_data.vertex_data[2] = {
		{0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}
	mesh_data.vertex_data[3] = {
		{-0.5, 0.5, 0.0},
		{0, 0, 0},
		colour
	}

	mesh_data.index_data = make([]u32, 5)
	defer delete(mesh_data.index_data)
	mesh_data.index_data[0] = 0
	mesh_data.index_data[1] = 1
	mesh_data.index_data[2] = 3
	mesh_data.index_data[3] = 2
	mesh_data.index_data[4] = 0

	mesh = MakeIndexedMesh(ctx, mesh_data)

	return 
}

create_mesh_from_file :: proc(using ctx: ^Context, file_name: string, instance_data: []Vec3) -> (meshID: MeshID) { 
	exists : bool
	mesh : ^IndexedMesh
	mesh_hash := hash.adler32(transmute([]u8)file_name)
	exists = mesh_hash in MeshTable
	if exists do return mesh_hash

	ok : ErrorCode

	mesh = new(IndexedMesh)


	mesh_data : IndexedMeshData
	mesh_data, ok = read_obj_mesh(file_name)
	assert(ok == .SUCCESS)

	mesh = MakeIndexedMesh(ctx, mesh_data)
	mesh.triangles = cast(u32)len(mesh_data.index_data) / 3

	MeshTable[mesh_hash] = mesh
	return mesh_hash
}

DestroyMeshes :: proc(renderer: ^Context) {
	for index, mesh in MeshTable {
		destroy_indexed_mesh(renderer, mesh)
	}
}
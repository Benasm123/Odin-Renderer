package vulkan_renderer

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:strconv"
import vk "vendor:vulkan"

make_file_path :: proc(folder : string, file : string) -> (path : string) {
    builder := strings.builder_make(0, len(folder) + len(file) + 1)
    strings.write_string(&builder, folder)
    strings.write_string(&builder, "/")
    strings.write_string(&builder, file)
    return strings.to_string(builder)
}

read_spirv :: proc(file_name : string) -> (code : []u8, err : ErrorCode = .SUCCESS) {
    parts : []string = {"Shaders/compiled/", file_name}
    old_path := strings.join(parts, "")
    file_contents2, ok2 := os.read_entire_file(old_path, context.allocator)
    assert(ok2)

    path : string = make_file_path("Shaders/compiled", file_name)

    file_contents, ok := os.read_entire_file(path, context.allocator)

    if (!ok) {
        fmt.println("Failed to read file ", file_name)
        return {}, .FAILURE
    }

    return file_contents, err
}

read_mesh :: proc(file_name : string) -> (mesh : IndexedMeshData, err: ErrorCode = .SUCCESS) {
    file_type := (strings.cut(file_name, strings.last_index(file_name, "."), 0))

    switch file_type {
        case ".obj":
            return read_obj_mesh(file_name)
        case ".fbx":
            return read_fbx_mesh(file_name)
        case:
            fmt.println("Unsupported filetype: ", file_type)
            assert(false)
    }

    return {}, err
}

read_obj_mesh :: proc(file_name : string) -> (mesh : IndexedMeshData, err: ErrorCode = .SUCCESS) {
    fmt.println("Reading OBJ: ", file_name)

    file_path := make_file_path("Meshes", file_name)

    file_contents, ok := os.read_entire_file(file_path, context.allocator)
    assert(ok, "Failed to read file")

    defer delete(file_contents, context.allocator)

    data := string(file_contents)

    vertex_count := 0
    texture_count := 0
    normal_count := 0
    face_count := 0
    index_count := 0

    // Count vertices and indicies first to allocate the memory
    // MARKER Can also use dynamic arrays, should time both to see which is faster.
    // MARKER Will only create vertices for number of unique vertices in file, however faces will have different normals.
    for line in strings.split_lines_iterator(&data) {
        parts := strings.split(line, " ")

        switch parts[0] {
            case "v":
                vertex_count += 1
            case "vt":
                texture_count += 1
            case "vn":
                normal_count += 1
            case "f":
                face_count += 1
                index_count += 3
                if len(parts) > 4 {
                    index_count += 3 * (len(parts) - 4)
                }
            case:
                continue
        }
    }

    fmt.println("Vertices:", vertex_count)
    fmt.println("Indices:", index_count)

    mesh.vertex_data = make([]Vertex, vertex_count)
    mesh.index_data = make([]u32, index_count)
    normals := make([]Vec3, normal_count)
    texture_coords := make([]Vec2, texture_count)

    vertex_normal_count := make([]u32, vertex_count)
    fmt.println("Made arrays")
    defer delete(vertex_normal_count)

    vertex_count = 0
    texture_count = 0
    normal_count = 0
    face_count = 0
    index_count = 0

    data = string(file_contents)

    for line in strings.split_lines_iterator(&data) {
        parts := strings.split(line, " ")

        switch parts[0] {
            case "v":
                x, y, z : f32
                ok : bool
                x, ok = strconv.parse_f32(parts[1])
                assert(ok, "Failed reading vertex")
                y, ok = strconv.parse_f32(parts[2])
                assert(ok, "Failed reading vertex")
                z, ok = strconv.parse_f32(parts[3])
                assert(ok, "Failed reading vertex")
                mesh.vertex_data[vertex_count].pos = {x, y, z}

                vertex_count += 1
            case "vt":
                x, y : f32
                ok : bool
                x, ok = strconv.parse_f32(parts[1])
                assert(ok, "Failed reading texture")
                y, ok = strconv.parse_f32(parts[2])
                assert(ok, "Failed reading texture")
                texture_coords[texture_count] = {x, y}

                texture_count += 1
            case "vn":
                x, y, z : f32
                ok : bool
                x, ok = strconv.parse_f32(parts[1])
                assert(ok, "Failed reading normal")
                y, ok = strconv.parse_f32(parts[2])
                assert(ok, "Failed reading normal")
                z, ok = strconv.parse_f32(parts[3])
                assert(ok, "Failed reading normal")
                normals[normal_count] = {x, y, z}

                normal_count += 1
            case "f":
                // If Triangle
                if (len(parts) == 4) {
                    index := 1
                    for index < len(parts) {
                        face_indices := strings.split(parts[index], "/")

                        vertex_index, texture_index, normal_index : uint
                        ok : bool
                        vertex_index, ok = strconv.parse_uint(face_indices[0])
                        texture_index, ok = strconv.parse_uint(face_indices[1])
                        normal_index, ok = strconv.parse_uint(face_indices[2])

                        mesh.index_data[index_count] = cast(u32)vertex_index - 1
                        mesh.vertex_data[vertex_index - 1].normal += normals[normal_index - 1]
                        vertex_normal_count[vertex_index - 1] += 1

                        index += 1

                        index_count += 1
                    }
                } else if len(parts) == 5 { // Quad
                    // FIRST
                    face1_indices := strings.split(parts[1], "/")
                    vertex1_index, texture1_index, normal1_index : uint
                    ok : bool

                    vertex1_index, ok = strconv.parse_uint(face1_indices[0])
                    texture1_index, ok = strconv.parse_uint(face1_indices[1])
                    normal1_index, ok = strconv.parse_uint(face1_indices[2])

                    mesh.index_data[index_count] = cast(u32)vertex1_index - 1
                    mesh.vertex_data[vertex1_index - 1].normal += normals[normal1_index - 1]
                    vertex_normal_count[vertex1_index - 1] += 1

                    index_count += 1

                    // SECOND
                    face2_indices := strings.split(parts[2], "/")
                    vertex2_index, texture2_index, normal2_index : uint

                    vertex2_index, ok = strconv.parse_uint(face2_indices[0])
                    texture2_index, ok = strconv.parse_uint(face2_indices[1])
                    normal2_index, ok = strconv.parse_uint(face2_indices[2])

                    mesh.index_data[index_count] = cast(u32)vertex2_index - 1
                    mesh.vertex_data[vertex2_index - 1].normal += normals[normal2_index - 1]
                    vertex_normal_count[vertex2_index - 1] += 1

                    index_count += 1

                    // THIRD
                    face3_indices := strings.split(parts[3], "/")
                    vertex3_index, texture3_index, normal3_index : uint

                    vertex3_index, ok = strconv.parse_uint(face3_indices[0])
                    texture3_index, ok = strconv.parse_uint(face3_indices[1])
                    normal3_index, ok = strconv.parse_uint(face3_indices[2])

                    mesh.index_data[index_count] = cast(u32)vertex3_index - 1
                    mesh.vertex_data[vertex3_index - 1].normal += normals[normal3_index - 1]
                    vertex_normal_count[vertex3_index - 1] += 1
                    
                    index_count += 1

                    // RE-ADD THIRD AND SECOND
                    mesh.index_data[index_count] = cast(u32)vertex3_index - 1
                    index_count += 1
                    mesh.index_data[index_count] = cast(u32)vertex2_index - 1
                    index_count += 1

                    // FOURTH
                    face4_indices := strings.split(parts[4], "/")
                    vertex4_index, texture4_index, normal4_index : uint

                    vertex4_index, ok = strconv.parse_uint(face4_indices[0])
                    texture4_index, ok = strconv.parse_uint(face4_indices[1])
                    normal4_index, ok = strconv.parse_uint(face4_indices[2])

                    mesh.index_data[index_count] = cast(u32)vertex4_index - 1
                    mesh.vertex_data[vertex4_index - 1].normal += normals[normal4_index - 1]
                    vertex_normal_count[vertex4_index - 1] += 1
                    
                    index_count += 1
                }

                face_count += 1
            case:
                continue
        }
    }

    for vertex, index in mesh.vertex_data {
        mesh.vertex_data[index].normal /= cast(f32)vertex_normal_count[index]
    }

    return mesh, err
}

read_fbx_mesh :: proc(file_name : string) -> (mesh : IndexedMeshData, err: ErrorCode = .SUCCESS) {
    fmt.println("Reading FBX: ", file_name)
    // mesh = new(Mesh)

    file_path := make_file_path("Meshes", file_name)

    return {}, err
}

get_memory_from_properties :: proc(using ctx: ^Context, properties: vk.MemoryPropertyFlags) -> (u32) {
	available_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &available_properties)

	for i in 0..<available_properties.memoryTypeCount {
		if (available_properties.memoryTypes[i].propertyFlags & properties) == properties {
			return i
		}
	}

	fmt.println("Failed to find supported memory.")

	return 0
}
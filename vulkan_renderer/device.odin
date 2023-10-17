package vulkan_renderer

import "core:fmt"
import vk "vendor:vulkan"

find_best_physical_device :: proc(using ctx: ^Context) -> ErrorCode {
    physical_device_count: u32 = 0
    vk.EnumeratePhysicalDevices(instance, &physical_device_count, nil)
    physical_devices := make([]vk.PhysicalDevice, physical_device_count)
    defer delete(physical_devices)
    vk.EnumeratePhysicalDevices(instance, &physical_device_count, raw_data(physical_devices))

    when ODIN_DEBUG { // Print all available devices
        fmt.println("Availble Physical Devices:")
    }

    evaluate_physcial_device :: proc(physical_device: vk.PhysicalDevice) -> int {
        physical_device_properties: vk.PhysicalDeviceProperties
        vk.GetPhysicalDeviceProperties(physical_device, &physical_device_properties)

        physical_device_features: vk.PhysicalDeviceFeatures;
        vk.GetPhysicalDeviceFeatures(physical_device, &physical_device_features)

        physical_device_memory_properties: vk.PhysicalDeviceMemoryProperties
        vk.GetPhysicalDeviceMemoryProperties(physical_device, &physical_device_memory_properties)

        when ODIN_DEBUG {
            fmt.print("\t")
			for char_ind in physical_device_properties.deviceName do fmt.print(rune(char_ind))
			fmt.print("\n")
        }
        // MARKER required features check here.
        if !physical_device_features.geometryShader do return 0;
        if !physical_device_features.tessellationShader do return 0;

        score := 0
        if physical_device_properties.deviceType == .DISCRETE_GPU do score += 1000;
        for heap_index in 0 ..< physical_device_memory_properties.memoryHeapCount {
            score += int(physical_device_memory_properties.memoryHeaps[heap_index].size / 10_000_000)
        }

        return score
    }

    best_score: int

    for available_physical_device in physical_devices {
        score := evaluate_physcial_device(available_physical_device)
        if score > best_score {
            physical_device = available_physical_device
            best_score = score
        }
    }
    
    if best_score == 0 do return .FAILURE

    return .SUCCESS
}

get_queue_families :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    queue_family_properties_count: u32
    vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_properties_count, nil)
    queue_family_properties := make([]vk.QueueFamilyProperties, queue_family_properties_count)
    defer delete(queue_family_properties)
    vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_properties_count, raw_data(queue_family_properties))

    available_graphics_queues : [dynamic]int
    available_compute_queues : [dynamic]int

    for property, index in queue_family_properties {
        if .GRAPHICS in property.queueFlags {
            append(&available_graphics_queues, index)
        }
        if .COMPUTE in property.queueFlags {
            append(&available_compute_queues, index)
        }
    }

    taken_queue_indexes : [dynamic]int

    if len(available_graphics_queues) == 0 do return .FAILURE
    if len(available_compute_queues) == 0 do return .FAILURE

    // WEAK_TODO Can be improved, but not too impactful

    contains_int :: proc(arr: [dynamic]int, val: int) -> (contains: bool = false) {
        for num in arr do if num == val do return true
        return
    }
    
    if len(available_graphics_queues) == 1 {
        queue_indices[.GRAPHICS] = available_graphics_queues[0]
    }
    else {
        for index in available_graphics_queues do if !(contains_int(taken_queue_indexes, index)) {queue_indices[.GRAPHICS] = index}
    }
    if len(available_compute_queues) == 1 { 
        queue_indices[.COMPUTE] = available_compute_queues[0]
    }
    else {
        for index in available_compute_queues do if !(contains_int(taken_queue_indexes, index)) { queue_indices[.COMPUTE] = index}
    }

    fmt.println("Queue Families Used:", queue_indices)

    return
}

create_device :: proc(using ctx: ^Context) -> (err: ErrorCode = .SUCCESS) {
    priorities: [1]f32 = {1.0}

    queue_create_infos: [QueueFamilyType]vk.DeviceQueueCreateInfo
    queue_create_infos[.GRAPHICS].sType = .DEVICE_QUEUE_CREATE_INFO
    queue_create_infos[.GRAPHICS].queueFamilyIndex = u32(queue_indices[.GRAPHICS])
    queue_create_infos[.GRAPHICS].queueCount = 1
    queue_create_infos[.GRAPHICS].pQueuePriorities = &priorities[0]

    queue_create_infos[.COMPUTE].sType = .DEVICE_QUEUE_CREATE_INFO
    queue_create_infos[.COMPUTE].queueFamilyIndex = u32(queue_indices[.COMPUTE])
    queue_create_infos[.COMPUTE].queueCount = 1
    queue_create_infos[.COMPUTE].pQueuePriorities = &priorities[0]

    features: vk.PhysicalDeviceFeatures
    features.geometryShader = true
    features.tessellationShader = true

    device_info: vk.DeviceCreateInfo
    device_info.sType = .DEVICE_CREATE_INFO
    device_info.queueCreateInfoCount = len(queue_create_infos)
    device_info.pQueueCreateInfos = &(queue_create_infos[QueueFamilyType(0)])
    device_info.enabledLayerCount = len(INSTANCE_LAYERS)
    device_info.ppEnabledLayerNames = raw_data(INSTANCE_LAYERS[:])
    device_info.enabledExtensionCount = len(DEVICE_EXTENSIONS)
    device_info.ppEnabledExtensionNames = len(DEVICE_EXTENSIONS) > 0 ? &DEVICE_EXTENSIONS[0] : nil
    device_info.pEnabledFeatures = &features

    vk.CreateDevice(physical_device, &device_info, nil, &device)
    
	vk.load_proc_addresses(device)

    for queue_type in QueueFamilyType {
        vk.GetDeviceQueue(device, cast(u32)queue_indices[queue_type], 0, &queues[queue_type])
    }

    fmt.println("Created Device")
    return
}
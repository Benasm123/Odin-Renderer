package vulkan_renderer

import "core:fmt"
import "core:os"
import vk "vendor:vulkan"
import sdl "vendor:sdl2"

create_instance :: proc(using ctx: ^Context) -> ErrorCode {
	vk.load_proc_addresses(sdl.Vulkan_GetVkGetInstanceProcAddr())

	app_info: vk.ApplicationInfo;
	app_info.sType = .APPLICATION_INFO;
	app_info.pApplicationName = "HEIST";
	app_info.applicationVersion = vk.MAKE_VERSION(0, 0, 1);
	app_info.pEngineName = "No Engine";
	app_info.engineVersion = vk.MAKE_VERSION(1, 0, 0);
	app_info.apiVersion = vk.API_VERSION_1_3;
	
	create_info: vk.InstanceCreateInfo;
	create_info.sType = .INSTANCE_CREATE_INFO;
	create_info.pApplicationInfo = &app_info;

	sdl_cnt : u32 = 0
	sdl.Vulkan_GetInstanceExtensions(window, &sdl_cnt, nil)
	// Make the array the size of sdl extensions + the extensions we want to add.
	enabled_instance_extensions := make([]cstring, sdl_cnt + len(INSTANCE_EXTENSION))
	defer delete(enabled_instance_extensions)
	sdl.Vulkan_GetInstanceExtensions(window, &sdl_cnt, raw_data(enabled_instance_extensions))

	// Add any additional wanted extensions to the sdl extensions.
	for i in int(sdl_cnt) ..< len(enabled_instance_extensions) {
		enabled_instance_extensions[i] = INSTANCE_EXTENSION[int(sdl_cnt) - i]
	}

	when ODIN_DEBUG { // Print used instance layers and extensions
		fmt.printf("Layers({}):\n", len(INSTANCE_LAYERS))
		for lay in INSTANCE_LAYERS do fmt.println("\t", lay)

		fmt.printf("Extensions({}):\n", len(enabled_instance_extensions))
		for ext in enabled_instance_extensions do fmt.println("\t", ext)
	}

	create_info.enabledExtensionCount = cast(u32)len(enabled_instance_extensions);
	create_info.ppEnabledExtensionNames = len(enabled_instance_extensions) > 0 ? raw_data(enabled_instance_extensions) : nil
	
	when ODIN_DEBUG // Validate Layers used
	{
		layer_count: u32;
		vk.EnumerateInstanceLayerProperties(&layer_count, nil);
		layers := make([]vk.LayerProperties, layer_count);
		defer delete(layers)
		vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layers));

		fmt.println("Available Layers:")
		for layer in layers {
			fmt.print("\t")
			for char_ind in layer.layerName do fmt.print(rune(char_ind))
			fmt.print("\n")
		} 
		
		outer: for name in INSTANCE_LAYERS
		{
			for layer in &layers
			{
				if name == cstring(&layer.layerName[0]) do continue outer;
			}
			fmt.eprintf("ERROR: validation layer %q not available\n", name);
			os.exit(1);
		}
		fmt.println("Validated Layers");
	}	
		
	create_info.enabledLayerCount = len(INSTANCE_LAYERS);
	create_info.ppEnabledLayerNames = raw_data(INSTANCE_LAYERS[:])

	if (vk.CreateInstance(&create_info, nil, &instance) != .SUCCESS)
	{
		fmt.eprintf("ERROR: Failed to create instance\n");
		return .FAILURE;
	}
	
	// Load Instance Function Pointers.
	vk.load_proc_addresses(instance)
	
	fmt.println("Instance Created");
	fmt.println("SAMPLE COUNT: ", sample_count)
	return .SUCCESS
}
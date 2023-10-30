package vulkan_renderer

Transform :: struct {
	position: Vec3,
	rotation: Vec3,
	scale: Vec3
}

State :: enum {
    IDLE, ACTIVE, DEAD
}

// This is the game object all other game object classes should add as using.
GameObject :: struct {
    transform : Transform, // TODO -> Change this to transform, current clash with mesh class.
    parent : ^GameObject
}

// A game object with a mesh which does not change during its lifetime. 
StaticMesh :: struct {
    using gameObject : GameObject,
    meshID : MeshID,
    state : State,
}
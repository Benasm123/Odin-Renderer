#version 430 core

layout (location = 0) in vec3 i_position;
layout (location = 1) in vec3 i_normal;
layout (location = 2) in vec3 i_tex;

layout (location = 3) in vec3 instance_offset;

layout( push_constant ) uniform constants
{
	mat4 mvp;
} PushConstants;

layout (location = 3) out vec4 colour;



void main(void) 
{	
	gl_Position = vec4(i_position + instance_offset, 1.0f) * PushConstants.mvp;
	colour = vec4(i_normal, 1.0f);
}
#version 430 core

layout (location = 0) in vec3 i_position;
layout (location = 1) in vec3 i_normal;
layout (location = 2) in vec3 i_tex;

layout( push_constant ) uniform constants
{
	mat4 mvp;
} PushConstants;

layout (location = 3) out vec4 colour;



void main(void) 
{	
	//if (gl_VertexIndex == 0) gl_Position = vec4(0.5, -0.5, 0.0, 1.0) * PushConstants.mvp;
	//if (gl_VertexIndex == 1) gl_Position = vec4(-0.5, -0.5, 0.0, 1.0) * PushConstants.mvp;
	//if (gl_VertexIndex == 2) gl_Position = vec4(0.5, 0.5, 0.0, 1.0) * PushConstants.mvp;

	gl_Position = vec4(i_position, 1.0f) * PushConstants.mvp;
	//float angle = clamp(pow(dot(vec3(3.0f, 10.0f, 1.0f), i_normal) / 10, 1), 0, 1);
	//vec3 col = vec3(0.2f, 0.5f, 0.65f);
	//colour = vec4(col * angle, 1.0f);
	//colour = vec4((i_normal + 1.0) / 2.0, 1.0f);
	//colour = vec4(1.0f, 0.0f, 0.0f, 1.0f);
	colour = vec4(i_tex, 1.0f);
}
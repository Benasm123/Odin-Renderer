package math_utils

import "core:fmt"
import "core:math"

Mat4 :: matrix[4, 4]f32
Vec3 :: [3]f32

identity_matrix_4x4 :: Mat4{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
}

make_translation_matrix :: proc(t: [3]f32) -> (Mat4) {
	return matrix[4, 4]f32{
		1, 		0, 		0, 		0,
		0, 		1, 		0, 		0,
		0, 		0, 		1, 		0,
		t[0],   t[1],   t[2], 	    1
	}
}

make_scale_matrix :: proc(s: Vec3) -> (Mat4) {
	return Mat4{
		s[0], 0,    0,    0,
		0,    s[1], 0,    0,
		0,    0,    s[2], 0,
		0,    0,    0,    1
	}
}

cross3 :: proc(first, second : [3]f32) -> (res : [3]f32) {
    return {
        (first[1] * second[2]) - (second[1] * first[2]),
        (first[0] * second[2]) - (second[0] * first[2]),
        (first[0] * second[1]) - (second[0] * first[1])
        }
}

dot3 :: proc(first, second : [3]f32) -> (res : f32) {
    return first.x * second.x + first.y * second.y + first.z * second.z
}

dimension :: enum {
	X, Y, Z
}

normalize_vec3 :: proc(vec: [3]f32) -> (res : [3]f32) {
    sum : f32 = 0.0
    for i in vec {
        sum = sum + (i * i)
    }

    mag : f32 = math.sqrt_f32(sum)

    for i, index in vec {
        res[index] = i / mag
    }

    return res
}

make_rotation_matrix :: proc(dim: dimension, r: f32) -> (Mat4) {
	switch dim {
		case .X: // X
			return matrix[4, 4]f32{
				1, 0, 		         0,               0,
				0, math.cos_f32(r),  math.sin_f32(r), 0,
				0, -math.sin_f32(r), math.cos_f32(r), 0,
				0, 0,                0,               1
			}
		case .Y: // Y
			return matrix[4, 4]f32{
				math.cos_f32(r), 0, -math.sin_f32(r), 0,
				0,               1, 0,                0,
				math.sin_f32(r), 0, math.cos_f32(r),  0,
				0,               0, 0,                1
			}
		case .Z: // Z
			return matrix[4, 4]f32{
				math.cos_f32(r), 0, -math.sin_f32(r), 0,
				0,               1, 0,                0,
				math.sin_f32(r), 0, math.cos_f32(r),  0,
				0,               0, 0,                1
			}
	}
	
	fmt.println("Cant rotate dimensions higher than 2(Z).")
	assert(false)
	return matrix[4, 4]f32{}
}

make_euler_rotation :: proc(angles: [3]f32) -> (Mat4) {
	return make_rotation_matrix(.Y, angles[0]) * make_rotation_matrix(.X, angles[1]) * make_rotation_matrix(.Z, angles[2])
}

to_radians :: proc(degrees: f32) -> (radians: f32) {
	return degrees * (math.PI / 180)
}
package math_utils

Quaternion :: struct {

}

/*









	axis_r : Vec3 = ({0, 1, 0})
	quat_p : quaternion128 = quaternion(0, gun.transform.position.x, gun.transform.position.y, gun.transform.position.z)
	theta : f32 = bdm.to_radians(1)

	sin_theta := math.sin_f32(theta/2)
	mag := math.sqrt(math.pow(axis_r.x, 2) + math.pow(axis_r.y, 2) + math.pow(axis_r.z, 2))

	quat_q : quaternion128 = quaternion(math.cos_f32(theta/2), sin_theta * (axis_r.x / mag), sin_theta * (axis_r.y / mag), sin_theta * (axis_r.z / mag))

	fmt.println(quat_q)
	fmt.println((quat_q.x * quat_q.x) + (quat_q.y * quat_q.y) + (quat_q.z * quat_q.z) + (quat_q.w * quat_q.w))


	
    quat_p.x = gun.transform.position.x
    quat_p.y = gun.transform.position.y
    quat_p.z = gun.transform.position.z
    
    sin_theta = math.sin_f32(theta / 2)
    mag = math.sqrt(math.pow(axis_r.x, 2) + math.pow(axis_r.y, 2) + math.pow(axis_r.z, 2))

    quat_q = quaternion(math.cos_f32(theta / 2), sin_theta * (axis_r.x / mag), sin_theta * (axis_r.y / mag), sin_theta * (axis_r.z / mag))

    quat_res := quat_q * quat_p * conj(quat_q)
    // gun.transform.position = {quat_res.x, quat_res.y, quat_res.z} //* cast(f32)delta_time 











 */
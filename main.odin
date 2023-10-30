package main

import "core:fmt"
import app "application"

Vec3 ::[3]f32

main :: proc() {
	application : app.Application
	app.Init(&application)
	app.Run(&application)
	fmt.println("Application Shutting Down!")
}
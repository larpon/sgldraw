// Copyright(C) 2021-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module plot

import math
import sokol.sgl

pub enum Plot {
	outline
	solid
}

[inline]
pub fn point(x f32, y f32) {
	sgl.v2f(x, y)
}

[inline]
pub fn line(x1 f32, y1 f32, x2 f32, y2 f32) {
	sgl.v2f(x1, y1)
	sgl.v2f(x2, y2)
}

[inline]
pub fn rectangle(x f32, y f32, w f32, h f32) {
	sgl.v2f(x, y)
	sgl.v2f((x + w), y)
	sgl.v2f((x + w), (y + h))
	sgl.v2f(x, (y + h))
}

[inline]
pub fn arc(x f32, y f32, radius f32, start_angle_in_rad f32, angle_in_rad f32, steps u32, plot Plot) {
	theta := f32(angle_in_rad / f32(steps))
	tan_factor := math.tanf(theta)
	rad_factor := math.cosf(theta)
	mut x1 := f32(radius * math.cosf(start_angle_in_rad))
	mut y1 := f32(radius * math.sinf(start_angle_in_rad))
	for i := 0; i < steps + 1; i++ {
		sgl.v2f(x1 + x, y1 + y)
		if plot == .solid {
			sgl.v2f(x, y)
		}
		tx := -y1
		ty := x1
		x1 += tx * tan_factor
		y1 += ty * tan_factor
		x1 *= rad_factor
		y1 *= rad_factor
	}
}

[inline]
pub fn arc_line(x f32, y f32, radius f32, width f32, start_angle_in_rad f32, angle_in_rad f32, steps u32) {
	mut theta := f32(0)
	for i := 0; i < steps; i++ {
		theta = start_angle_in_rad + angle_in_rad * f32(i) / f32(steps)
		mut x1 := (radius + width) * math.cosf(theta)
		mut y1 := (radius + width) * math.sinf(theta)
		mut x2 := (radius - width) * math.cosf(theta)
		mut y2 := (radius - width) * math.sinf(theta)
		sgl.v2f(x + x1, y + y1)
		sgl.v2f(x + x2, y + y2)
		theta = start_angle_in_rad + angle_in_rad * f32(i + 1) / f32(steps)
		mut nx1 := (radius + width) * math.cosf(theta)
		mut ny1 := (radius + width) * math.sinf(theta)
		mut nx2 := (radius - width) * math.cosf(theta)
		mut ny2 := (radius - width) * math.sinf(theta)
		sgl.v2f(x + nx1, y + ny1)
		sgl.v2f(x + nx2, y + ny2)
	}
}

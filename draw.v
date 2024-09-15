// Copyright(C) 2021-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module sgldraw

import sokol.sgl
import sokol.sapp

const cache = &Cache{}

pub const dpi_scale_factor = dpi_scale()

// Color
pub struct Color {
pub mut:
	r u8
	g u8
	b u8
	a u8
}

pub struct Colors {
pub mut:
	solid   Color
	outline Color
}

@[flag]
pub enum Fill {
	invisible
	outline
	solid
	debug
}

@[flag]
pub enum Cap {
	butt
	round
	square
}

@[flag]
pub enum Connect {
	miter
	bevel
	round
}

fn dpi_scale() f32 {
	mut s := sapp.dpi_scale()
	//$if android {
	//	s *= android_dpi_scale()
	//}
	// NB: on older X11, `Xft.dpi` from ~/.Xresources, that sokol uses,
	// may not be set which leads to sapp.dpi_scale reporting incorrectly 0.0
	if s < 0.1 {
		s = 1.0
	}
	return s
}

@[inline]
pub fn rgb(r u8, g u8, b u8) Color {
	return Color{r, g, b, u8(255)}
}

@[inline]
pub fn rgba(r u8, g u8, b u8, a u8) Color {
	return Color{r, g, b, a}
}

@[inline]
pub fn push_matrix() {
	sgl.push_matrix()
}

@[inline]
pub fn pop_matrix() {
	sgl.pop_matrix()
}

@[inline]
pub fn translate(x f32, y f32, z f32) {
	sgl.translate(x, y, z)
}

@[inline]
pub fn rotate(angle_in_rad f32, x f32, y f32, z f32) {
	sgl.rotate(angle_in_rad, x, y, z)
}

@[inline]
pub fn scale(x f32, y f32, z f32) {
	sgl.scale(x, y, z)
}

struct Cache {
mut:
	images map[string]Image
	// fonts  map[string]FontCache
}

fn (c Cache) has_image(id string) bool {
	return id in c.images.keys()
}

fn (c Cache) get_image(id string) Image {
	return c.images[id] or { panic('get_image failed to get ${id} from cache') }
}

fn (mut c Cache) free() {
	for _, mut img in c.images {
		img.free()
	}
}

pub fn free() {
	unsafe {
		mut c := cache
		c.free()
	}
	// unsafe { C.free(c) }
}

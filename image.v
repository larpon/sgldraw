// Copyright(C) 2021-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module sgldraw

import os
import sokol.gfx
import stbi

pub struct ImageLoadOptions {
mut:
	width  int
	height int

	cache   bool = true
	mipmaps int
	path    string
}

[heap]
pub struct Image {
pub:
	width  int
	height int
mut:
	cache bool

	path string

	channels int
	ready    bool
	mipmaps  int

	data voidptr
	ext  string

	sg_image gfx.Image
}

fn load_image(opt ImageLoadOptions) ?Image {
	// eprintln(@MOD+'.'+@STRUCT+'.'+@FN+' loading "${opt.path}" ...')

	mut image_path := opt.path

	uid := image_path
	if cache.has_image(uid) {
		// eprintln(@MOD+'.'+@STRUCT+'.'+@FN+' loading "$image_path" from cache')
		mut img := cache.get_image(uid)
		if !img.ready {
			mut buffer := []u8{}
			image_path = img.path
			$if android {
				image_path = image_path.replace('assets/', '') // TODO
				buffer = os.read_apk_asset(image_path) or {
					return error(@MOD + '.' + @FN + ' (Android) file "${image_path}" not found')
				}
			} $else {
				if !os.is_file(image_path) {
					return error(@MOD + '.' + @FN + ' file "${image_path}" not found')
					// return none
				}
				image_path = os.real_path(image_path)
				buffer = os.read_bytes(image_path) or {
					return error(@MOD + '.' + @FN + ' file "${image_path}" could not be read')
				}
			}

			// stb_img := stbi.load(opt.path) or { return err }
			stb_img := stbi.load_from_memory(buffer.data, buffer.len) or {
				return error(@MOD + '.' + @FN + ' stbi failed loading "${image_path}"')
			}

			img = Image{
				width: stb_img.width
				height: stb_img.height
				channels: stb_img.nr_channels
				cache: opt.cache
				ready: stb_img.ok
				data: stb_img.data
				ext: stb_img.ext
				path: opt.path
				mipmaps: opt.mipmaps
			}
			img.init_sokol_image()
			// stb_img.free() // TODO ??

			if img.cache {
				eprintln(@MOD + '.' + @STRUCT + '.' + @FN + ' caching "${uid}"')
				unsafe {
					mut c := cache
					c.images[uid] = img
				}
			}
			return img
		}
		return img
	}

	mut buffer := []u8{}
	$if android {
		image_path = image_path.replace('assets/', '') // TODO
		buffer = os.read_apk_asset(image_path) or {
			return error(@MOD + '.' + @FN + ' (Android) file "${image_path}" not found')
		}
	} $else {
		if !os.is_file(image_path) {
			return error(@MOD + '.' + @FN + ' file "${image_path}" not found')
			// return none
		}
		image_path = os.real_path(image_path)
		buffer = os.read_bytes(image_path) or {
			return error(@MOD + '.' + @FN + ' file "${image_path}" could not be read')
		}
	}

	stb_img := stbi.load_from_memory(buffer.data, buffer.len) or {
		return error(@MOD + '.' + @FN + ' stbi failed loading "${image_path}"')
	}

	mut img := Image{
		width: stb_img.width
		height: stb_img.height
		channels: stb_img.nr_channels
		cache: opt.cache
		ready: stb_img.ok
		data: stb_img.data
		ext: stb_img.ext
		path: opt.path
		mipmaps: opt.mipmaps
	}
	img.init_sokol_image()
	// stb_img.free() // TODO ??

	eprintln(@MOD + '.' + @FN + ' loaded "${img.path}" ...')

	if img.cache && !cache.has_image(uid) {
		eprintln(@MOD + '.' + @FN + ' caching "${uid}"')
		unsafe {
			mut c := cache
			c.images[uid] = img
		}
	}

	return img
}

fn (mut img Image) init_sokol_image() {
	// eprintln('\n init sokol image $img.path ok=$img.sg_image_ok')
	mut img_desc := gfx.ImageDesc{
		width: img.width
		height: img.height
		num_mipmaps: img.mipmaps
		wrap_u: .clamp_to_edge
		wrap_v: .clamp_to_edge
		label: &u8(0)
		d3d11_texture: 0
		pixel_format: .rgba8 // C.SG_PIXELFORMAT_RGBA8
	}

	img_desc.data.subimage[0][0] = gfx.Range{
		ptr: img.data
		size: usize(img.channels * img.width * img.height)
	}

	if img.mipmaps <= 0 {
		img.sg_image = gfx.make_image(&img_desc)
	}
}

pub fn (mut img Image) free() {
	unsafe {
		gfx.destroy_image(img.sg_image)
		C.stbi_image_free(img.data)
	}
}

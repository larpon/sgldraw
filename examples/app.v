// Copyright(C) 2020-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module main

import os
import math
import time
import sokol.sapp
import sokol.gfx
import sokol.sgl
import sgldraw as draw

fn main() {
	mut app := &App{
		width:       1000
		height:      600
		pass_action: gfx.create_clear_pass_action(0.6, 0.5, 0.4, 1.0)
	}
	app.run()
}

@[heap]
struct App {
	pass_action gfx.PassAction
mut:
	d          Debug
	ticks      i64
	dt         f32
	width      int
	height     int
	frame      i64
	last       i64
	alpha_pip  sgl.Pipeline
	keys_state map[sapp.KeyCode]bool
	ready      bool
	canvas     Canvas
	m_x        f32
	m_y        f32
}

struct Canvas {
pub mut:
	x    f32
	y    f32
	zoom f32 = 1
	zp_x f32
	zp_y f32
	// Test values
	rx     f32
	ry     f32
	size_w f32 = 100
	size_h f32 = 100
}

fn (mut c Canvas) reset() {
	c.x = 0
	c.y = 0
	c.zoom = 1
	c.zp_x = 0
	c.zp_y = 0
	c.rx = 0
	c.ry = 0
	c.size_w = 100
	c.size_h = 100
}

fn (mut a App) init() {
	a.frame = 0
	a.last = time.ticks()

	sgl.load_pipeline(a.alpha_pip)

	a.ready = true
}

fn (mut a App) quit() {
	sapp.quit()
}

fn (mut a App) cleanup() {
	draw.free()
}

fn (mut a App) run() {
	title := 'sgldraw'
	desc := sapp.Desc{
		width:               a.width
		height:              a.height
		user_data:           a
		init_userdata_cb:    init
		frame_userdata_cb:   frame
		event_userdata_cb:   event
		window_title:        title.str
		html5_canvas_name:   title.str
		cleanup_userdata_cb: cleanup
		sample_count:        4
	}
	sapp.run(&desc)
}

fn (mut a App) on_resized() {
}

fn (mut a App) on_mouse_wheel(x f32, y f32) {
	if a.key_is_held(.left_control) || a.key_is_held(.right_control) {
		a.canvas.zp_x = a.m_x //-a.canvas.x // TODO proper inverse matrix value
		a.canvas.zp_y = a.m_y //-a.canvas.y // TODO proper inverse matrix value
		a.canvas.zoom += y * 0.15
	} else if a.key_is_held(.right_shift) {
		a.canvas.x += -y * 10 * 4
	} else {
		a.canvas.y += y * 10 * 4
	}
}

fn (mut a App) handle_input() {
	if a.key_is_held(.right) {
		a.canvas.rx += 10
	}
	if a.key_is_held(.left) {
		a.canvas.rx -= 10
	}
	if a.key_is_held(.up) {
		a.canvas.ry -= 10
	}
	if a.key_is_held(.down) {
		a.canvas.ry += 10
	}
}

fn (a App) key_is_held(kc sapp.KeyCode) bool {
	return kc in a.keys_state.keys() && a.keys_state[kc]
}

fn (mut a App) on_key_down(ev &sapp.Event) {
	a.keys_state[ev.key_code] = true

	if ev.key_code == .r {
		a.canvas.reset()
	}

	if ev.key_code == .s {
		stamp := time.now().format_ss().replace(' ', '_').replace(':', '').replace('-',
			'')
		sapp.screenshot(os.join_path(os.temp_dir(), 'screenshot.${stamp}.png')) or { panic(err) }
	}

	// Debug input
	if a.key_is_held(.period) {
		if ev.key_code == .comma {
			eprintln(a.d.flags)
			return
		}

		if ev.key_code == .f {
			a.d.toggle(.flood)
		}

		// Debug draw control
		if a.key_is_held(.d) {
			a.d.on(.draw)
			if ev.key_code == .minus || a.key_is_held(.minus) {
				a.d.off(.draw)
			} else {
			}
		}

		// Debug print control
		if a.key_is_held(.p) {
			a.d.on(.print)

			if ev.key_code == .a {
				a.d.toggle(.app)
			} else if ev.key_code == .i {
				a.d.toggle(.input)
			} else if ev.key_code == .minus || a.key_is_held(.minus) {
				a.d.pln(.debug_state, 'print off')
				a.d.off(.print)
			} else {
			}
		}
	}
}

fn (mut a App) on_key_up(ev &sapp.Event) {
	a.keys_state[ev.key_code] = false

	// Handle quit event
	if ev.key_code == .escape || ev.key_code == .q {
		a.quit()
		return
	}

	//
	if ev.key_code == .f {
		sapp.toggle_fullscreen()
		return
	}
}

fn init(user_data voidptr) {
	mut app := unsafe { &App(user_data) }

	desc := sapp.create_desc()
	gfx.setup(&desc)
	sgl_desc := sgl.Desc{
		max_vertices: 50 * 65536
	}
	sgl.setup(&sgl_desc)
	mut pipdesc := gfx.PipelineDesc{}
	unsafe { C.memset(&pipdesc, 0, sizeof(pipdesc)) }

	color_state := gfx.ColorTargetState{
		blend: gfx.BlendState{
			enabled:        true
			src_factor_rgb: .src_alpha
			dst_factor_rgb: .one_minus_src_alpha
		}
	}
	pipdesc.colors[0] = color_state

	app.alpha_pip = sgl.make_pipeline(&pipdesc)

	app.init()
}

fn cleanup(user_data voidptr) {
	mut app := unsafe { &App(user_data) }
	app.cleanup()
	gfx.shutdown()
}

fn frame(user_data voidptr) {
	mut app := unsafe { &App(user_data) }
	app.frame++

	t := time.ticks()
	app.ticks = t
	app.dt = f32(t - app.last) / 1000.0

	if app.width != sapp.width() || app.height != sapp.height() {
		app.d.pln(.app, 'resized from ${app.width}x${app.height} to ${sapp.width()}x${sapp.height()}')
		app.on_resized()
		app.width = sapp.width()
		app.height = sapp.height()
	}

	app.handle_input()
	app.draw()

	pass := sapp.create_default_pass(app.pass_action)
	gfx.begin_pass(&pass)
	sgl.default_pipeline()
	sgl.draw()
	gfx.end_pass()
	gfx.commit()

	app.last = t
}

fn event(ev &sapp.Event, mut a App) {
	if ev.@type == .mouse_move {
		a.m_x = ev.mouse_x
		a.m_y = ev.mouse_y
	}
	if ev.@type == .key_up {
		a.on_key_up(ev)
	}
	if ev.@type == .key_down {
		a.on_key_down(ev)
	}
	if ev.@type == .touches_began || ev.@type == .touches_moved {
		if ev.num_touches > 0 {
			touch_point := ev.touches[0]
			a.d.pln(.input, '${touch_point}')
			//
		}
	}
	if ev.scroll_x != 0 || ev.scroll_y != 0 {
		a.on_mouse_wheel(ev.scroll_x, ev.scroll_y)
	}
}

fn (a App) draw() {
	if !a.ready {
		return
	}
	a.d.plng(.draw | .flood, @STRUCT + '.' + @FN + '() called dT: ${a.dt} ...')

	sgl.defaults()

	sgl.load_pipeline(a.alpha_pip)

	sgl.ortho(0, f32(sapp.width()), f32(sapp.height()), 0.0, -100, 100.0)

	size_w := f32(100)
	size_h := f32(100)

	s := f32(a.canvas.zoom)
	bs := f32(1)

	t_x := a.canvas.x
	t_y := a.canvas.y

	draw.translate(t_x, t_y, 0)
	draw.translate(a.canvas.zp_x, a.canvas.zp_y, 0)
	draw.scale(s, s, 1)
	draw.translate(-a.canvas.zp_x, -a.canvas.zp_y, 0)

	wb := draw.Shape{
		scale: bs
		// connect: .round
	}
	mut wbr := draw.Shape{
		scale:   bs
		connect: .round //.miter //.round //.bevel
		radius:  4.5
		colors:  draw.Colors{draw.rgba(0, 0, 0, 127), draw.rgba(255, 255, 255, 127)}
	}

	grey_blue := draw.Shape{
		scale:  bs
		colors: draw.Colors{draw.rgb(127, 127, 127), draw.rgb(0, 0, 127)}
	}

	thick_line := draw.Shape{
		scale:  bs
		radius: 4
		colors: draw.Colors{draw.rgba(0, 127, 25, 127), draw.rgba(0, 127, 25, 127)}
	}

	dbgf := if a.d.all(.draw) { draw.Fill.debug } else { draw.Fill.invisible }
	debug_brush := draw.Shape{
		scale:  bs
		fill:   dbgf
		colors: draw.Colors{draw.rgba(0, 0, 125, 25), draw.rgba(0, 0, 125, 25)}
	}

	arx := a.canvas.rx
	ary := a.canvas.ry

	grey_blue.rectangle(arx, ary, size_w, size_h)

	wbr.rounded_rectangle(arx * 1.1 + 50, ary * 1.1 + 50, size_w, size_h, 20)

	//
	sgl.push_matrix()

	circle_x := arx * 0.8 + 200
	circle_y := ary * 0.8 + 70

	draw.translate(circle_x, circle_y, 0)
	rot_y := loopf(f32(a.frame) * 0.02, sgl.rad(0), sgl.rad(360))

	draw.rotate(rot_y, 0.0, 1.0, 0.0)
	draw.translate(-circle_x, -circle_y, 0)

	wbr.colors.solid = draw.rgba(225, 120, 0, 127)
	wbr.circle(circle_x, circle_y, 20, 40)
	sgl.pop_matrix()
	//

	wbr.colors.solid = draw.rgba(0, 0, 0, 127)
	wbr.ellipse(arx * 0.8 + 400, ary * 0.8 + 60, 40, 80, 50)

	wbr.arc(600, 500, 50, 0 * draw.deg2rad, 90 * draw.deg2rad)

	wbr.triangle(20, 20, 50, 30, 25, 65)

	wbr.rectangle(100 + arx * 1.1, 400 + ary * 1.1, size_w * 0.5, size_h * 0.5)
	wbr.line(arx + 280, ary + 200, arx + 500, ary + 200 + 200)

	wbr.poly([f32(0), 0, 100, 0, 150, 50, 110, 70, 80, 50, 40, 60, 0, 10], []int{}, arx + 150,
		ary + 100 * 1.1)

	wbr.poly([f32(0), 0, 40, -40, 100, 0, 150, 50, 110, 70, 80, 50, 40, 60, 0, 10, 20, 5, 40, -2,
		70, 32, 32, 20], [8], arx + 150, ary + 300)

	wbr.convex_poly([f32(0), 0, 100, 0, 150, 50, 150, 80, 80, 100, 0, 50], arx + 400 * 1.1,
		ary + 400 * 1.1)

	wbr.uniform_segment_poly(800, 500, 60, 5)

	wbr.segment_poly(200, 550, 40, 60, 8)

	wb.image(arx + 200, ary, size_w * 0.5, size_h * 0.5, os.resource_abs_path(os.join_path('..',
		'img', 'logo.png')))

	thick_line.line(arx + 200, ary + 200, arx + 400, ary + 200 + 200 * ary * 0.051)
	wb.line(arx + 200, ary + 200, arx + 400, ary + 200 + 200 * ary * 0.051)

	thick_line.line(arx + 200, ary + 200, arx + 600, ary + 200)
	wb.line(arx + 200, ary + 200, arx + 600, ary + 200)

	// if a.d.all(.draw) {
	debug_brush.rectangle(arx, ary, size_w, size_h)
	//}
}

@[inline]
fn loopf(value f32, from f32, to f32) f32 {
	range := to - from
	offset_value := value - from // value relative to 0
	// + `from` to reset back to start of original range
	return (offset_value - f32((math.floor(offset_value / range) * range))) + from
}

// Debug stuff

@[flag]
pub enum Flag {
	app
	print
	flood
	input
	draw
	debug_state
}

struct Debug {
mut:
	flags Flag = .print | .input | .app | .debug_state
}

fn (d Debug) all(flags Flag) bool {
	return d.flags.all(flags)
}

fn (d Debug) has(flags Flag) bool {
	return d.flags.has(flags)
}

fn (mut d Debug) on(flag Flag) {
	if !d.has(flag) {
		d.flags.set(flag)
		d.pln(.debug_state, flag.str().all_after('.').trim_right('}') + ' ${d.state(flag)}')
	}
}

fn (mut d Debug) off(flag Flag) {
	if d.has(flag) {
		d.flags.clear(flag)
		d.pln(.debug_state, flag.str().all_after('.').trim_right('}') + ' ${d.state(flag)}')
	}
}

fn (mut d Debug) toggle(flag Flag) {
	d.flags.toggle(flag)
	d.pln(.debug_state, flag.str().all_after('.').trim_right('}') + ' ${d.state(flag)}')
}

fn (d Debug) state(flag Flag) string {
	return if d.has(flag) { 'on' } else { 'off' }
}

@[if !prod]
fn (d Debug) pln(flag Flag, str string) {
	if !d.flags.has(.print) {
		return
	}
	if d.flags.has(flag) {
		f := flag.str().all_after('.').trim_right('}')
		println(f + ' ' + str)
	}
}

@[if !prod]
fn (d Debug) plng(flag Flag, str string) {
	if !d.flags.has(.print) {
		return
	}
	if d.flags & flag == flag {
		f := flag.str().all_after('.').trim_right('}').split(' | ').join('')
		println(f + ' ' + str)
	}
}

// Copyright(C) 2021-2022 Lars Pontoppidan. All rights reserved.
// Use of this source code is governed by an MIT license file distributed with this software package
module sgldraw

import plot
import sokol.sgl
import math
import earcut

pub const (
	deg2rad = f32((math.pi * 2) / 360)
	rad2deg = f32(360 / (math.pi * 2))
)

const (
	rad_max     = 2 * math.pi
	deg90rad    = 90 * deg2rad
	debug_shape = Shape{
		colors: Colors{rgba(255, 0, 0, 55), rgba(255, 0, 0, 55)}
	}
	no_indicies = []int{len: 0, cap: 0}
)

pub struct Shape {
pub mut:
	radius   f32     = 1.0
	scale    f32     = 1.0
	fill     Fill    = .solid | .outline
	cap      Cap     = .butt
	connect  Connect = .bevel
	offset_x f32     = 0.0
	offset_y f32     = 0.0
	colors   Colors  = Colors{rgba(0, 0, 0, 255), rgba(255, 255, 255, 127)}
}

pub fn (mut b Shape) set_colors(outline Color, solid Color) {
	b.colors.outline = outline
	b.colors.solid = solid
}

[inline]
pub fn (b Shape) rectangle(x f32, y f32, w f32, h f32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor
	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	if b.fill.has(.solid) {
		c := b.colors.solid
		sgl.c4b(c.r, c.g, c.b, c.a)
		sgl.begin_quads()
		sgl.v2f(sx, sy)
		sgl.v2f((sx + w), sy)
		sgl.v2f((sx + w), (sy + h))
		sgl.v2f(sx, (sy + h))
		sgl.end()
	}
	if b.fill.has(.outline) {
		if b.radius > 1 {
			m12x, m12y := midpoint(sx, sy, sx + w, sy)
			m23x, m23y := midpoint(sx + w, sy, sx + w, sy + h)
			m34x, m34y := midpoint(sx + w, sy + h, sx, sy + h)
			m41x, m41y := midpoint(sx, sy + h, sx, sy)
			b.anchor(m12x, m12y, sx + w, sy, m23x, m23y)
			b.anchor(m23x, m23y, sx + w, sy + h, m34x, m34y)
			b.anchor(m34x, m34y, sx, sy + h, m41x, m41y)
			b.anchor(m41x, m41y, sx, sy, m12x, m12y)
		} else {
			sgl.c4b(b.colors.outline.r, b.colors.outline.g, b.colors.outline.b, b.colors.outline.a)
			sgl.begin_line_strip()
			sgl.v2f(sx, sy)
			sgl.v2f((sx + w), sy)
			sgl.v2f((sx + w), (sy + h))
			sgl.v2f(sx, (sy + h))
			sgl.v2f(sx, (sy - 1))
			sgl.end()
		}
	}
	if b.fill.has(.debug) {
		sgldraw.debug_shape.rectangle(x, y, w, h)
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) line(x1 f32, y1 f32, x2 f32, y2 f32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	c := b.colors.outline
	sgl.c4b(c.r, c.g, c.b, c.a)

	x1_ := x1 * scale_factor
	y1_ := y1 * scale_factor
	dx := x1 - x1_
	dy := y1 - y1_
	x2_ := x2 - dx
	y2_ := y2 - dy
	if scale_factor != 1 {
		push_matrix()
		translate(x1_, y1_, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-x1_, -y1_, 0)
	}
	if b.radius > 1 {
		radius := b.radius

		mut tl_x := x1_ - x2_
		mut tl_y := y1_ - y2_
		tl_x, tl_y = perpendicular(tl_x, tl_y)
		tl_x, tl_y = normalize(tl_x, tl_y)
		tl_x *= radius
		tl_y *= radius
		tl_x += x1_
		tl_y += y1_

		tr_x := tl_x - x1_ + x2_
		tr_y := tl_y - y1_ + y2_

		mut bl_x := x2_ - x1_
		mut bl_y := y2_ - y1_
		bl_x, bl_y = perpendicular(bl_x, bl_y)
		bl_x, bl_y = normalize(bl_x, bl_y)
		bl_x *= radius
		bl_y *= radius
		bl_x += x1_
		bl_y += y1_

		br_x := bl_x - x1_ + x2_
		br_y := bl_y - y1_ + y2_

		/*
		sgl.c4b(255, 0, 0, 200)
		raw.rectangle(bl_x-1,br_y-1,2,2)
		raw.rectangle(tl_x-1,tl_y-1,2,2)
		raw.rectangle(tr_x-1,tr_y-1,2,2)
		raw.rectangle(br_x-1,br_y-1,2,2)
		*/

		sgl.c4b(c.r, c.g, c.b, c.a)

		sgl.begin_quads()
		sgl.v2f(tl_x, tl_y)
		sgl.v2f(tr_x, tr_y)
		sgl.v2f(br_x, br_y)
		sgl.v2f(bl_x, bl_y)
		sgl.end()
	} else {
		sgl.begin_line_strip()
		sgl.v2f(x1_, y1_)
		sgl.v2f(x2_, y2_)
		sgl.end()
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) uniform_segment_poly(x f32, y f32, radius f32, steps u32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor

	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	mut c := b.colors.solid
	sgl.c4b(c.r, c.g, c.b, c.a)
	mut theta := f32(0)
	mut xx := f32(0)
	mut yy := f32(0)
	if b.fill.has(.solid) {
		sgl.begin_triangle_strip()
		for i := 0; i < steps + 1; i++ {
			theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
			xx = radius * math.cosf(theta)
			yy = radius * math.sinf(theta)
			sgl.v2f(xx + sx, yy + sy)
			sgl.v2f(sx, sy)
		}
		sgl.end()
	}
	if b.fill.has(.outline) {
		c = b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)
		if b.radius > 1 || scale_factor != 1 {
			for i := 0; i < steps; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				x1 := sx + (radius * math.cosf(theta))
				y1 := sy + (radius * math.sinf(theta))
				theta = 2.0 * f32(math.pi) * f32(i + 1) / f32(steps)
				x2 := sx + (radius * math.cosf(theta))
				y2 := sy + (radius * math.sinf(theta))
				theta = 2.0 * f32(math.pi) * f32(i + 2) / f32(steps)
				x3 := sx + (radius * math.cosf(theta))
				y3 := sy + (radius * math.sinf(theta))

				m12x, m12y := midpoint(x1, y1, x2, y2)
				m23x, m23y := midpoint(x2, y2, x3, y3)

				b.anchor(m12x, m12y, x2, y2, m23x, m23y)
			}
		} else {
			sgl.begin_line_strip()
			for i := 0; i < steps + 1; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				xx = radius * math.cosf(theta)
				yy = radius * math.sinf(theta)
				sgl.v2f(xx + sx, yy + sy)
			}
			sgl.end()
		}
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) segment_poly(x f32, y f32, radius_x f32, radius_y f32, steps u32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor
	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	mut c := b.colors.solid
	sgl.c4b(c.r, c.g, c.b, c.a)
	mut theta := f32(0)
	mut xx := f32(0)
	mut yy := f32(0)
	if b.fill.has(.solid) {
		sgl.begin_triangle_strip()
		for i := 0; i < steps + 1; i++ {
			theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
			xx = radius_x * math.cosf(theta)
			yy = radius_y * math.sinf(theta)
			sgl.v2f(xx + sx, yy + sy)
			sgl.v2f(sx, sy)
		}
		sgl.end()
	}
	if b.fill.has(.outline) {
		c = b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)
		if b.radius > 1 {
			for i := 0; i < steps; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				x1 := sx + (radius_x * math.cosf(theta))
				y1 := sy + (radius_y * math.sinf(theta))
				theta = 2.0 * f32(math.pi) * f32(i + 1) / f32(steps)
				x2 := sx + (radius_x * math.cosf(theta))
				y2 := sy + (radius_y * math.sinf(theta))
				theta = 2.0 * f32(math.pi) * f32(i + 2) / f32(steps)
				x3 := sx + (radius_x * math.cosf(theta))
				y3 := sy + (radius_y * math.sinf(theta))

				m12x, m12y := midpoint(x1, y1, x2, y2)
				m23x, m23y := midpoint(x2, y2, x3, y3)

				b.anchor(m12x, m12y, x2, y2, m23x, m23y)
			}
		} else {
			sgl.begin_line_strip()
			for i := 0; i < steps + 1; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				xx = radius_x * math.cosf(theta)
				yy = radius_y * math.sinf(theta)
				sgl.v2f(xx + sx, yy + sy)
			}
			sgl.end()
		}
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
fn (b Shape) uniform_line_segment_poly(x f32, y f32, radius f32, steps u32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor

	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	mut c := b.colors.solid
	sgl.c4b(c.r, c.g, c.b, c.a)
	mut theta := f32(0)
	mut xx := f32(0)
	mut yy := f32(0)
	if b.fill.has(.solid) {
		sgl.begin_triangle_strip()
		for i := 0; i < steps + 1; i++ {
			theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
			xx = radius * math.cosf(theta)
			yy = radius * math.sinf(theta)
			sgl.v2f(xx + sx, yy + sy)
			sgl.v2f(sx, sy)
		}
		sgl.end()
	}
	if b.fill.has(.outline) {
		c = b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)
		if b.radius > 1 || scale_factor != 1 {
			sgl.begin_triangle_strip()
			for i := 0; i < steps; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				mut x1 := ((radius + b.radius) * math.cosf(theta))
				mut y1 := ((radius + b.radius) * math.sinf(theta))
				mut x2 := ((radius - b.radius) * math.cosf(theta))
				mut y2 := ((radius - b.radius) * math.sinf(theta))
				sgl.v2f(sx + x1, sy + y1)
				sgl.v2f(sx + x2, sy + y2)
				theta = 2.0 * f32(math.pi) * f32(i + 1) / f32(steps)
				mut nx1 := ((radius + b.radius) * math.cosf(theta))
				mut ny1 := ((radius + b.radius) * math.sinf(theta))
				mut nx2 := ((radius - b.radius) * math.cosf(theta))
				mut ny2 := ((radius - b.radius) * math.sinf(theta))
				sgl.v2f(sx + nx1, sy + ny1)
				sgl.v2f(sx + nx2, sy + ny2)
			}
			sgl.end()
		} else {
			sgl.begin_line_strip()
			for i := 0; i < steps + 1; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				xx = radius * math.cosf(theta)
				yy = radius * math.sinf(theta)
				sgl.v2f(xx + sx, yy + sy)
			}
			sgl.end()
		}
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
fn (b Shape) line_segment_poly(x f32, y f32, radius_x f32, radius_y f32, steps u32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor
	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	mut c := b.colors.solid
	sgl.c4b(c.r, c.g, c.b, c.a)
	mut theta := f32(0)
	mut xx := f32(0)
	mut yy := f32(0)
	if b.fill.has(.solid) {
		sgl.begin_triangle_strip()
		for i := 0; i < steps + 1; i++ {
			theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
			xx = radius_x * math.cosf(theta)
			yy = radius_y * math.sinf(theta)
			sgl.v2f(xx + sx, yy + sy)
			sgl.v2f(sx, sy)
		}
		sgl.end()
	}
	if b.fill.has(.outline) {
		c = b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)
		if b.radius > 1 {
			sgl.begin_triangle_strip()
			for i := 0; i < steps; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				mut x1 := ((radius_x + b.radius) * math.cosf(theta))
				mut y1 := ((radius_y + b.radius) * math.sinf(theta))
				mut x2 := ((radius_x - b.radius) * math.cosf(theta))
				mut y2 := ((radius_y - b.radius) * math.sinf(theta))
				sgl.v2f(sx + x1, sy + y1)
				sgl.v2f(sx + x2, sy + y2)

				theta = 2.0 * f32(math.pi) * f32(i + 1) / f32(steps)
				mut nx1 := ((radius_x + b.radius) * math.cosf(theta))
				mut ny1 := ((radius_y + b.radius) * math.sinf(theta))
				mut nx2 := ((radius_x - b.radius) * math.cosf(theta))
				mut ny2 := ((radius_y - b.radius) * math.sinf(theta))
				sgl.v2f(sx + nx1, sy + ny1)
				sgl.v2f(sx + nx2, sy + ny2)
			}
			sgl.end()
		} else {
			sgl.begin_line_strip()
			for i := 0; i < steps + 1; i++ {
				theta = 2.0 * f32(math.pi) * f32(i) / f32(steps)
				xx = radius_x * math.cosf(theta)
				yy = radius_y * math.sinf(theta)
				sgl.v2f(xx + sx, yy + sy)
			}
			sgl.end()
		}
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) circle(x f32, y f32, radius f32, steps u32) {
	b.uniform_line_segment_poly(x, y, radius, u32(sgldraw.rad_max * radius))
}

[inline]
pub fn (b Shape) ellipse(x f32, y f32, radius_x f32, radius_y f32, steps u32) {
	b.line_segment_poly(x, y, radius_x, radius_y, u32(sgldraw.rad_max * math.max(radius_x,
		radius_y)))
}

[direct_array_access; inline]
pub fn (b Shape) convex_poly(points []f32, offset_x f32, offset_y f32) {
	b.poly(points, sgldraw.no_indicies, offset_x, offset_y)
}

[direct_array_access; inline]
pub fn (b Shape) poly(points []f32, holes []int, offset_x f32, offset_y f32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	off_x := offset_x * scale_factor
	off_y := offset_y * scale_factor
	if scale_factor != 1 {
		push_matrix()
		translate(off_x, off_y, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-off_x, -off_y, 0)
	}

	dim := 2
	if b.fill.has(.solid) {
		color := b.colors.solid
		sgl.c4b(color.r, color.g, color.b, color.a)

		mut indicies := earcut.earcut(points, holes, dim)
		sgl.begin_triangles()
		for i := 0; i < indicies.len; i += 3 {
			x1 := off_x + points[indicies[i] * dim]
			y1 := off_y + points[indicies[i] * dim + 1]

			x2 := off_x + points[indicies[i + 1] * dim]
			y2 := off_y + points[indicies[i + 1] * dim + 1]

			x3 := off_x + points[indicies[i + 2] * dim]
			y3 := off_y + points[indicies[i + 2] * dim + 1]

			sgl.v2f(x1, y1)
			sgl.v2f(x2, y2)
			sgl.v2f(x3, y3)
		}
		sgl.end()
	}

	if b.fill.has(.outline) {
		mut hole_start := points.len
		if holes.len > 0 {
			hole_start = holes[0] * dim
		}
		mut x1 := off_x + points[hole_start - 2]
		mut y1 := off_y + points[hole_start - 1]
		mut x2 := off_x + points[0]
		mut y2 := off_y + points[1]
		mut x3 := f32(0)
		mut y3 := f32(0)
		c := b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)

		if b.radius > 1 {
			for i := 0; i < hole_start; i += dim {
				x1 = off_x + points[loop(i, 0, hole_start)]
				y1 = off_y + points[loop(i + 1, 0, hole_start)]
				x2 = off_x + points[loop(i + 2, 0, hole_start)]
				y2 = off_y + points[loop(i + 3, 0, hole_start)]
				x3 = off_x + points[loop(i + 4, 0, hole_start)]
				y3 = off_y + points[loop(i + 5, 0, hole_start)]

				m12x, m12y := midpoint(x1, y1, x2, y2)
				m23x, m23y := midpoint(x2, y2, x3, y3)

				b.anchor(m12x, m12y, x2, y2, m23x, m23y)
			}

			for i := 0; i < holes.len; i++ {
				from := holes[i] * dim
				mut to := points.len
				if i + 1 < holes.len {
					to = holes[i + 1] * dim
				}
				for j := from; j < to; j += dim {
					x1 = off_x + points[loop(j, from, to)]
					y1 = off_y + points[loop(j + 1, from, to)]
					x2 = off_x + points[loop(j + 2, from, to)]
					y2 = off_y + points[loop(j + 3, from, to)]
					x3 = off_x + points[loop(j + 4, from, to)]
					y3 = off_y + points[loop(j + 5, from, to)]

					m12x, m12y := midpoint(x1, y1, x2, y2)
					m23x, m23y := midpoint(x2, y2, x3, y3)

					b.anchor(m12x, m12y, x2, y2, m23x, m23y)
				}
			}
		} else {
			sgl.begin_line_strip()
			for i := 0; i < points.len && i < hole_start; i += dim {
				sgl.v2f(x1, y1)
				sgl.v2f(x2, y2)

				x1 = off_x + points[i]
				y1 = off_y + points[i + 1]
				x2 = off_x + points[i + 2]
				y2 = off_y + points[i + 3]
			}
			sgl.end()

			sgl.begin_line_strip()
			for i := 0; i < holes.len; i++ {
				from := holes[i] * dim
				mut to := points.len - 2
				if i + 1 < holes.len {
					to = holes[i + 1] * dim
				}
				for j := from; j < to; j += dim {
					x1 = off_x + points[j]
					y1 = off_y + points[j + 1]
					x2 = off_x + points[j + 2]
					y2 = off_y + points[j + 3]

					sgl.v2f(x1, y1)
					sgl.v2f(x2, y2)
				}

				sgl.v2f(x2, y2)
				x1 = off_x + points[from]
				y1 = off_y + points[from + 1]
				sgl.v2f(x1, y1)
			}
			sgl.end()
		}
	}

	if b.fill.has(.debug) {
		mut indicies := earcut.earcut(points, holes, dim)
		for i := 0; i < indicies.len; i += 3 {
			x1 := off_x + points[indicies[i] * dim]
			y1 := off_y + points[indicies[i] * dim + 1]

			x2 := off_x + points[indicies[i + 1] * dim]
			y2 := off_y + points[indicies[i + 1] * dim + 1]

			x3 := off_x + points[indicies[i + 2] * dim]
			y3 := off_y + points[indicies[i + 2] * dim + 1]

			sgldraw.debug_shape.triangle(x1, y1, x2, y2, x3, y3)
		}

		/*
		for i := 0; i < points.len; i += 2 {
			debug_shape.rectangle(offset_x+points[i]*scale-1, offset_y+points[i+1]*scale-1, 2, 2)
		}*/
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) arc(x f32, y f32, radius f32, start_angle_in_rad f32, angle_in_rad f32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor
	sair := loopf(start_angle_in_rad - (90 * sgldraw.deg2rad), 0, sgldraw.rad_max)
	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	steps := (sair - angle_in_rad) * radius
	segdiv := u32(steps) // 4
	if b.fill.has(.solid) {
		c := b.colors.solid
		sgl.c4b(c.r, c.g, c.b, c.a)
		sgl.begin_triangle_strip()
		plot.arc(sx, sy, radius, sair, angle_in_rad, segdiv, .solid)
		sgl.end()
	}
	if b.fill.has(.outline) {
		c := b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)
		if b.radius <= 1 {
			sgl.begin_line_strip()
			plot.arc(sx, sy, radius, sair, angle_in_rad, segdiv, .outline)
			sgl.end()
		} else {
			sgl.begin_triangle_strip()
			plot.arc_line(sx, sy, radius, b.radius, sair, angle_in_rad, segdiv)
			sgl.end()
		}
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) rounded_rectangle(x f32, y f32, w f32, h f32, radius f32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor
	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}
	r := radius
	steps := sgldraw.rad_max * r

	if b.fill.has(.solid) {
		c := b.colors.solid
		sgl.c4b(c.r, c.g, c.b, c.a)

		segdiv := u32(steps / 4)

		sgl.begin_triangle_strip()
		// left top
		lx := sx + r
		ly := sy + r
		plot.arc(lx, ly, r, 180 * sgldraw.deg2rad, sgldraw.deg90rad, segdiv, .solid)

		// right top
		rx := sx + w - r
		ry := sy + r
		sgl.v2f(rx, ry - r)
		sgl.v2f(rx, ry)
		plot.arc(rx, ry, r, 270 * sgldraw.deg2rad, sgldraw.deg90rad, segdiv, .solid)

		// right bottom
		rbx := rx
		rby := sy + h - r
		sgl.v2f(rbx + r, rby)
		sgl.v2f(rbx, rby)
		plot.arc(rbx, rby, r, 0, sgldraw.deg90rad, segdiv, .solid)

		// left bottom
		lbx := lx
		lby := sy + h - r
		sgl.v2f(lbx, lby + r)
		sgl.v2f(lbx, lby)
		plot.arc(lbx, lby, r, sgldraw.deg90rad, sgldraw.deg90rad, segdiv, .solid)

		sgl.v2f(lx - r, ly)
		sgl.v2f(lx, ly)

		sgl.end()

		sgl.begin_quads()
		sgl.v2f(lx, ly)
		sgl.v2f(rx, ry)
		sgl.v2f(rbx, rby)
		sgl.v2f(lbx, lby)
		sgl.end()
	}

	if b.fill.has(.outline) {
		c := b.colors.outline
		sgl.c4b(c.r, c.g, c.b, c.a)

		segdiv := u32(steps / 4)

		if b.radius <= 1 {
			// left top
			sgl.begin_line_strip()
			lx := sx + r
			ly := sy + r
			plot.arc(lx, ly, r, 180 * sgldraw.deg2rad, sgldraw.deg90rad, segdiv, .outline)
			rx := sx + w - r
			ry := sy + r
			// right top
			plot.arc(rx, ry, r, 270 * sgldraw.deg2rad, sgldraw.deg90rad, segdiv, .outline)
			rbx := rx
			rby := sy + h - r
			// right bottom
			plot.arc(rbx, rby, r, 0, sgldraw.deg90rad, segdiv, .outline)
			// left bottom
			lbx := lx
			lby := sy + h - r
			plot.arc(lbx, lby, r, sgldraw.deg90rad, sgldraw.deg90rad, segdiv, .outline)

			sgl.v2f(lx - r, ly)
			sgl.end()
		} else {
			sgl.begin_triangle_strip()
			// left top
			lx := sx + r
			ly := sy + r
			plot.arc_line(lx, ly, r, b.radius, 180 * sgldraw.deg2rad, sgldraw.deg90rad,
				segdiv)

			// right top
			rx := sx + w - r
			ry := sy + r
			sgl.v2f(rx, ry - (r + b.radius))
			sgl.v2f(rx, ry - (r - b.radius))
			plot.arc_line(rx, ry, r, b.radius, 270 * sgldraw.deg2rad, sgldraw.deg90rad,
				segdiv)

			// right bottom
			rbx := rx
			rby := sy + h - r
			sgl.v2f(rbx + (r + b.radius), rby)
			sgl.v2f(rbx + (r - b.radius), rby)
			plot.arc_line(rbx, rby, r, b.radius, 0, sgldraw.deg90rad, segdiv)

			// left bottom
			lbx := lx
			lby := sy + h - r
			sgl.v2f(lbx, lby + (r + b.radius))
			sgl.v2f(lbx, lby + (r - b.radius))
			plot.arc_line(lbx, lby, r, b.radius, sgldraw.deg90rad, sgldraw.deg90rad, segdiv)

			sgl.v2f(lx - (r + b.radius), ly)
			sgl.v2f(lx - (r - b.radius), ly)

			sgl.end()
		}
	}

	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) triangle(x1 f32, y1 f32, x2 f32, y2 f32, x3 f32, y3 f32) {
	scale_factor := b.scale * sgldraw.dpi_scale_factor
	x1_ := x1 * scale_factor
	y1_ := y1 * scale_factor
	dx := x1 - x1_
	dy := y1 - y1_
	x2_ := x2 - dx
	y2_ := y2 - dy
	x3_ := x3 - dx
	y3_ := y3 - dy

	if scale_factor != 1 {
		push_matrix()
		translate(x1_, y1_, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-x1_, -y1_, 0)
	}
	mut color := b.colors.solid
	sgl.c4b(color.r, color.g, color.b, color.a)

	if b.fill.has(.solid) {
		sgl.begin_triangles()
		sgl.v2f(x1_, y1_)
		sgl.v2f(x2_, y2_)
		sgl.v2f(x3_, y3_)
		sgl.end()
	}

	if b.fill.has(.outline) {
		if b.radius > 1 {
			m12x, m12y := midpoint(x1_, y1_, x2_, y2_)
			m23x, m23y := midpoint(x2_, y2_, x3_, y3_)
			m31x, m31y := midpoint(x3_, y3_, x1_, y1_)
			b.anchor(m12x, m12y, x2_, y2_, m23x, m23y)
			b.anchor(m23x, m23y, x3_, y3_, m31x, m31y)
			b.anchor(m31x, m31y, x1_, y1_, m12x, m12y)
		} else {
			color = b.colors.outline
			sgl.c4b(color.r, color.g, color.b, color.a)

			sgl.begin_line_strip()

			sgl.v2f(x1_, y1_)
			sgl.v2f(x2_, y2_)

			sgl.v2f(x2_, y2_)
			sgl.v2f(x3_, y3_)

			sgl.v2f(x3_, y3_)
			sgl.v2f(x1_, y1_)

			sgl.end()
		}
	}
	if scale_factor != 1 {
		pop_matrix()
	}
}

[inline]
pub fn (b Shape) image(x f32, y f32, w f32, h f32, path string) {
	img := load_image(path: path) or { return }
	if !img.ready {
		return
	}

	scale_factor := b.scale * sgldraw.dpi_scale_factor
	sx := x * scale_factor
	sy := y * scale_factor
	if scale_factor != 1 {
		push_matrix()
		translate(sx, sy, 0)
		scale(scale_factor, scale_factor, 1.0)
		translate(-sx, -sy, 0)
	}

	u0 := f32(0.0)
	v0 := f32(0.0)
	u1 := f32(1.0)
	v1 := f32(1.0)
	x0 := f32(0)
	y0 := f32(0)
	x1 := f32(w)
	y1 := f32(h)

	push_matrix()

	sgl.enable_texture()
	sgl.texture(img.sg_image)
	sgl.translate(f32(sx), f32(sy), 0)
	// sgl.c4b(p.color.r, p.color.g, p.color.b, p.color.a)
	sgl.c4b(255, 255, 255, 255)

	sgl.begin_quads()
	sgl.v2f_t2f(x0, y0, u0, v0)
	sgl.v2f_t2f(x1, y0, u1, v0)
	sgl.v2f_t2f(x1, y1, u1, v1)
	sgl.v2f_t2f(x0, y1, u0, v1)
	sgl.end()

	sgl.translate(-f32(sx), -f32(sy), 0)
	sgl.disable_texture()

	pop_matrix()

	if scale_factor != 1 {
		pop_matrix()
	}
}

// Utility functions for sgldraw.ng an anchor point

[inline]
fn (b Shape) anchor(x1 f32, y1 f32, x2 f32, y2 f32, x3 f32, y3 f32) {
	// Original author Chris H.F. Tsang / CPOL License
	// https://www.codeproject.com/Articles/226569/Drawing-polylines-by-tessellation
	// http://artgrammer.blogspot.com/search/label/opengl
	c := b.colors.outline
	sgl.c4b(c.r, c.g, c.b, c.a)
	radius := b.radius
	if radius == 1 {
		sgl.begin_line_strip()
		sgl.v2f(x1, y1)
		sgl.v2f(x2, y2)
		sgl.end()
		return
	}

	mut t0_x := x2 - x1
	mut t0_y := y2 - y1

	mut t2_x := x3 - x2
	mut t2_y := y3 - y2

	t0_x, t0_y = perpendicular(t0_x, t0_y)
	t2_x, t2_y = perpendicular(t2_x, t2_y)

	flip := signed_area(x1, y1, x2, y2, x3, y3) > 0
	if flip {
		t0_x = -t0_x
		t0_y = -t0_y

		t2_x = -t2_x
		t2_y = -t2_y
	}

	t0_x, t0_y = normalize(t0_x, t0_y)
	t2_x, t2_y = normalize(t2_x, t2_y)
	t0_x *= radius
	t0_y *= radius

	t2_x *= radius
	t2_y *= radius

	ip_x, ip_y, _ := intersect(t0_x + x1, t0_y + y1, t0_x + x2, t0_y + y2, t2_x + x3,
		t2_y + y3, t2_x + x2, t2_y + y2)

	vp_x := ip_x
	vp_y := ip_y

	vpp_x, vpp_y := rotate_point(x2, y2, vp_x, vp_y, 180 * sgldraw.deg2rad)

	/*
	sgl.c3b(155,0,0)
	if flip {
		raw.rectangle(vp_x-2,vp_y-2,4,4)
	} else {
		raw.rectangle(vpp_x-2,vpp_y-2,4,4)
	}
	sgl.c4b(c.r, c.g, c.b, c.a)
	*/

	t0_x += x1
	t0_y += y1

	at_x := t0_x - x1 + x2
	at_y := t0_y - y1 + y2

	t2_x += x3
	t2_y += y3

	bt_x := t2_x - x3 + x2
	bt_y := t2_y - y3 + y2

	t0r_x, t0r_y := rotate_point(x1, y1, t0_x, t0_y, 180 * sgldraw.deg2rad)
	t2r_x, t2r_y := rotate_point(x3, y3, t2_x, t2_y, 180 * sgldraw.deg2rad)

	// println('T0: $t0_x, $t0_y vP: $vp_x, $vp_y -vP: $vpp_x, $vpp_y')
	// sgl.c4b(c.r, c.g, c.b, 40)

	if b.connect.has(.miter) {
		sgl.begin_triangles()
		sgl.v2f(t0_x, t0_y)
		sgl.v2f(vp_x, vp_y)
		sgl.v2f(vpp_x, vpp_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t0r_x, t0r_y)
		sgl.v2f(t0_x, t0_y)

		sgl.v2f(vp_x, vp_y)
		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t2_x, t2_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t2r_x, t2r_y)
		sgl.v2f(t2_x, t2_y)
		sgl.end()
	} else if b.connect.has(.bevel) {
		sgl.begin_triangles()
		sgl.v2f(t0_x, t0_y)
		sgl.v2f(at_x, at_y)
		sgl.v2f(vpp_x, vpp_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t0r_x, t0r_y)
		sgl.v2f(t0_x, t0_y)

		sgl.v2f(at_x, at_y)
		sgl.v2f(bt_x, bt_y)
		sgl.v2f(vpp_x, vpp_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(bt_x, bt_y)
		sgl.v2f(t2_x, t2_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t2_x, t2_y)
		sgl.v2f(t2r_x, t2r_y)
		sgl.end()

		/*
		// NOTE Adding this will also end up in .miter
		sgl.v2f(at_x, at_y)
		sgl.v2f(vp_x, vp_y)
		sgl.v2f(bt_x, bt_y)
		*/
	} else {
		// .round
		// arc / rounded corners
		mut start_angle := line_segment_angle(vpp_x, vpp_y, at_x, at_y)
		mut arc_angle := line_segment_angle(vpp_x, vpp_y, bt_x, bt_y)
		arc_angle -= start_angle

		if arc_angle < 0 {
			if flip {
				arc_angle = arc_angle + 2.0 * math.pi
			}
		}
		sgl.begin_triangle_strip()
		plot.arc(vpp_x, vpp_y, line_segment_length(vpp_x, vpp_y, at_x, at_y), start_angle,
			arc_angle, u32(18), .solid)
		sgl.end()

		sgl.begin_triangles()

		sgl.v2f(t0_x, t0_y)
		sgl.v2f(at_x, at_y)
		sgl.v2f(vpp_x, vpp_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t0r_x, t0r_y)
		sgl.v2f(t0_x, t0_y)

		// TODO arc_points
		// sgl.v2f(at_x, at_y)
		// sgl.v2f(bt_x, bt_y)
		// sgl.v2f(vpp_x, vpp_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(bt_x, bt_y)
		sgl.v2f(t2_x, t2_y)

		sgl.v2f(vpp_x, vpp_y)
		sgl.v2f(t2_x, t2_y)
		sgl.v2f(t2r_x, t2r_y)

		sgl.end()
	}

	// Expected base lines
	/*
	sgl.c4b(0, 255, 0, 90)
	line(x1, y1, x2, y2)
	line(x2, y2, x3, y3)
	*/
}

[inline]
fn line_segment_angle(x1 f32, y1 f32, x2 f32, y2 f32) f32 {
	return math.pi + f32(math.atan2(y1 - y2, x1 - x2))
}

[inline]
fn line_segment_length(x1 f32, y1 f32, x2 f32, y2 f32) f32 {
	return math.sqrtf(((y2 - y1) * (y2 - y1)) + ((x2 - x1) * (x2 - x1)))
}

[inline]
fn rotate_point(cx f32, cy f32, px f32, py f32, angle_in_radians f32) (f32, f32) {
	s := math.sinf(angle_in_radians)
	c := math.cosf(angle_in_radians)
	mut npx := px
	mut npy := py
	// translate point back to origin:
	npx -= cx
	npy -= cy
	// rotate point
	xnew := npx * c - npy * s
	ynew := npx * s + npy * c
	// translate point back:
	npx = xnew + cx
	npy = ynew + cy
	return npx, npy
}

[inline]
fn midpoint(x1 f32, y1 f32, x2 f32, y2 f32) (f32, f32) {
	return (x1 + x2) / 2, (y1 + y2) / 2
}

[inline]
fn loop(value int, from int, to int) int {
	range := to - from
	offset_value := value - from // value relative to 0
	// + `from` to reset back to start of original range
	return (offset_value - int((math.floor(offset_value / range) * range))) + from
}

[inline]
fn loopf(value f32, from f32, to f32) f32 {
	range := to - from
	offset_value := value - from // value relative to 0
	// + `from` to reset back to start of original range
	return (offset_value - f32((math.floor(offset_value / range) * range))) + from
}

// perpendicular anti-clockwise 90 degrees
[inline]
fn perpendicular(x f32, y f32) (f32, f32) {
	return -y, x
}

[inline]
fn signed_area(x1 f32, y1 f32, x2 f32, y2 f32, x3 f32, y3 f32) f32 {
	return (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)
}

[inline]
fn normalize(x f32, y f32) (f32, f32) {
	w := math.sqrtf(x * x + y * y)
	return x / w, y / w
}

// x1, y1, x2, y2 = line 1
// x3, y3, x4, y4 = line 2
// output: (output point x,y, intersection type)
[inline]
fn intersect(x1 f32, y1 f32, x2 f32, y2 f32, x3 f32, y3 f32, x4 f32, y4 f32) (f32, f32, int) {
	// Determine the intersection point of two line steps
	// http://paulbourke.net/geometry/lineline2d/
	mut mua, mut mub := f32(0), f32(0)
	mut denom, mut numera, mut numerb := f32(0), f32(0), f32(0)
	eps := f32(0.000000000001)

	denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1)
	numera = (x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)
	numerb = (x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)

	if (-eps < numera && numera < eps) && (-eps < numerb && numerb < eps)
		&& (-eps < denom && denom < eps) {
		return (x1 + x2) * 0.5, (y1 + y2) * 0.5, 2 // meaning the lines coincide
	}

	if -eps < denom && denom < eps {
		return 0, 0, 0 // meaning lines are parallel
	}

	mua = numera / denom
	mub = numerb / denom
	px := x1 + mua * (x2 - x1)
	py := y1 + mua * (y2 - y1)
	out1 := mua < 0 || mua > 1
	out2 := mub < 0 || mub > 1

	if int(out1) & int(out2) == 0 {
		return px, py, 5 // the intersection lies outside both steps
	} else if out1 {
		return px, py, 3 // the intersection lies outside segment 1
	} else if out2 {
		return px, py, 4 // the intersection lies outside segment 2
	} else {
		return px, py, 1 // the intersection lies inside both steps
	}
}

fn gen_arc_points(start_angle f32, end_angle f32, radius f32, steps u32) []f32 {
	mut arc_points := []f32{len: int(steps) * 2}
	mut angle := start_angle
	arc_length := end_angle - start_angle
	for i := 0; i <= steps; i++ {
		x := math.sinf(angle) * radius
		y := math.cosf(angle) * radius

		arc_points << x
		arc_points << y

		angle += arc_length / steps
	}
	return arc_points
}

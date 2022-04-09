# sgldraw

`sgldraw` is a GPU accelerated, fairly performant, V module for
drawing vector shapes through `sokol.sgl`.

The example can be run with: `v run examples/app.v`:
![screenshot](https://raw.githubusercontent.com/Larpon/sgldraw/master/img/screenshot.png)

The special thing about `sgldraw` is that it's real-time - meaning that it'll draw all
shapes from scratch 60 frames per second.

It also handles line widths > 1 - which makes the shapes look more like they'd do in
e.g. Inkscape. All shapes can also be animated with `sgl` transforms or by changing
each vertice coordinate the shapes is made up from.

## Why
It was an experiment on doing real-time vector graphics and also
to explore a way to package vector shape drawing into a self-contained
and standalone module.

`sgldraw` has served as a personal sandbox but
I'm releasing it to the public in case some of the code might
be of interest to anyone.

## Install

```bash
git clone https://github.com/Larpon/sgldraw.git ~/.vmodules/sgldraw
```
When `sgldraw` is in `~/.vmodules/` you can run the examples and import
it as a normal V module with `import sgldraw`.

## Notes

**Legacy project**

It's not completely abandoned, but my focus is currently elsewhere
in V-land.

**Licenses**

Some code found in this module is adapted from code originally written by
Chris H.F. Tsang published under the [CPOL License](https://en.wikipedia.org/wiki/Code_Project_Open_License).

Also note that the `earcut` module is based on work licenced under the [ISC License](https://github.com/mapbox/earcut/blob/master/LICENSE).
The version of `earcut` is from [Larpon/earcut](https://github.com/Larpon/earcut/)@[1790a9e](https://github.com/Larpon/earcut/tree/1790a9e60dae09889b95b337acb205699fd4f51e).

Both CPOL and ISC are very permissive licenses that ressembles MIT

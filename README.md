# sgldraw

`sgldraw` is a GPU accelerated, fairly performant, V module for
drawing vector shapes through `sokol.sgl`.

![screenshot](https://github.com/Larpon/sgldraw/img/screenshot.png)

The special thing about `sgldraw` is that it can do real-time vector graphics - so
you can draw things like a polygon with line-width > 1. Drawn shapes can also
be animated with `sgl` transforms.

## Dependencies
[earcut](https://github.com/Larpon/earcut)

## Why
It was an experiment on doing real-time vector graphics and also
to explore a way to package vector shape drawing into a self-contained
and standalone module.

For maintainance reasons `earcut` is an external dependency but it can
easily be distributed as a submodule to `sgldraw` if need be.

`sgldraw` has served as a personal playground but
I'm releasing it to the public in case some of the code might
be of interest to anyone.

## Notes
**The module not supported and is more or less abandoned**

The example can be run with: `v run examples/app.v`

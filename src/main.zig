const capy = @import("capy");
const std = @import("std");
const stlLoader = @import("./libs/stl-loader-zig/stl-loader-zig.zig");
const render = @import("./render.zig");

const Allocator = std.mem.Allocator;
var allocator: Allocator = undefined;
var renderer: render.Renderer = undefined;
var lmbDown = false;
var rmbDown = false;
var prevX: i32 = 0;
var prevY: i32 = 0;
var textInput: *capy.TextField = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    allocator = gpa.allocator();
    defer _ = gpa.deinit();

    try capy.backend.init();

    textInput = capy.textField(.{});
    var window = try capy.Window.init();
    try window.set(
        capy.row(.{}, .{
            initCanvas(),
            capy.column( .{}, .{
                textInput,
                capy.button(.{ .label = "Set model", .onclick = &loadModel})
            }),
        }),
    );

    window.setTitle("Zig+Capy STL viewer");
    window.setPreferredSize(650, 500);
    window.show();
    capy.runEventLoop();

    if (renderer.mesh) |m| {allocator.free(m);}
}

pub fn initCanvas() !*capy.Canvas {
    var canvas = capy.canvas(.{ .preferredSize = capy.Size.init(500, 500)});
    renderer = render.Renderer{ .mesh = undefined, .width = undefined, .height = undefined };
    try canvas.addDrawHandler(&drawCanvas);
    try canvas.addMouseButtonHandler(&clickHandler);
    try canvas.addMouseMotionHandler(&motionHandler);
    return canvas;
}

pub fn drawCanvas(self: *capy.Canvas, ctx: *capy.DrawContext) anyerror!void {
    const dim = std.mem.min(u32, &[2]u32{self.getWidth(), self.getHeight()});
    renderer.width = dim;
    renderer.height = dim; 
    if (renderer.mesh) |_| {
        const processed_mesh = try renderer.render(allocator);
        for (processed_mesh) |t| {
            ctx.line(t.v1.x, t.v1.y, t.v2.x, t.v2.y);
            ctx.line(t.v2.x, t.v2.y, t.v3.x, t.v3.y);
            ctx.line(t.v3.x, t.v3.y, t.v1.x, t.v1.y);
        }
        allocator.free(processed_mesh);
    }
}

pub fn clickHandler(widget: *capy.Canvas, button: capy.MouseButton, pressed: bool, x: u32, y: u32) anyerror!void {
    switch (button) {
        .Left => {lmbDown = pressed;},
        .Right => {rmbDown = pressed;},
        .Middle => {},
        else => unreachable
    }
    _ = widget;
    _ = x;
    _ = y;
}

pub fn motionHandler(widget: *capy.Canvas, x: u32, y: u32) anyerror!void {
    if (x <= widget.getWidth() and y <= widget.getHeight() and x >= 0 and y >= 0) {
    const iX = @as(i32, @intCast(x));
    const iY = @as(i32, @intCast(y));
    const deltaX = @as(f32, @floatFromInt(iX - prevX));
    const deltaY = @as(f32, @floatFromInt(iY - prevY));
    prevX = iX;
    prevY = iY;

    if (lmbDown and rmbDown) {}
    else if (lmbDown) {
        renderer.cameraPosX += deltaX / 25;
        renderer.cameraPosY += deltaY / 25;
    } else if (rmbDown) {
        renderer.cameraRotZ += deltaX / 100;
        renderer.cameraRotX -= deltaY / 100;
    }

    try widget.requestDraw();
    }
}

pub fn loadModel(widget: *anyopaque) anyerror!void {
    const inputPath = textInput.getText();
    if (renderer.mesh) |m| {allocator.free(m);}
    renderer.mesh = try stlLoader.load_stl(allocator, inputPath);
    _ = widget;
}

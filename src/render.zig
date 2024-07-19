// thanks to https://gamedev.stackexchange.com/a/25588 for the base projection code

const std = @import("std");
const zmath = @import("zmath");
const stlLoader = @import("libs/stl-loader-zig/stl-loader-zig.zig");
const Allocator = std.mem.Allocator;

pub const Renderer = struct {
  posX: f32 = 0,
  posY: f32 = 0,
  posZ: f32 = 0,

  rotX: f32 = 0,
  rotY: f32 = 0,
  rotZ: f32 = 0,

  cameraPosX: f32 = 0,
  cameraPosY: f32 = 0,
  cameraPosZ: f32 = 0,

  cameraRotX: f32 = 0,
  cameraRotY: f32 = 0,
  cameraRotZ: f32 = 0,

  width: u32,
  height: u32,

  mesh: ?[]stlLoader.Triangle,

  pub fn render(self: Renderer, allocator: Allocator) ![]projectedTriangle {
    var projectedTriangles = std.ArrayList(projectedTriangle).init(allocator);

    if (self.mesh) |m| {
    const comboMatrix = zmath.mul(try self.setupWorld(), try self.setupCamera());

    for(m) |t| {
      var transformedVertices: [3]Point2 = undefined;
      var valid = true;
      for(0..3) |j| {
          var v: stlLoader.Point = undefined;
          switch (j) {
            0 => {v = t.v1;},
            1 => {v = t.v2;},
            2 => {v = t.v3;},
            else => unreachable
          }

          // 4d vector / homogenous representation for vertex, 1 row matrix
          // result has n of cols of comboMatrix (4) and n of rows of globalMesh / vertex (1)
          const currentVertex = zmath.mul(zmath.f32x4(v.x, v.y, v.z, 1), comboMatrix);

          // weak projection
          const px = currentVertex[0] / currentVertex [2];
          const py = currentVertex[1] / currentVertex [2];

          // oob check
          if (px > 1 or px < -1 or py > 1 or py < -1) {  
            valid = false;
            break;
          }

          // scale to viewport size
          const finalVertex = Point2{
            .x = @as(i32, @intFromFloat(@round(px * (@as(f32, @floatFromInt(self.width))/2) + (@as(f32, @floatFromInt(self.width))/2)))),
            .y = @as(i32, @intFromFloat(@round(py * (@as(f32, @floatFromInt(self.height))/2) + (@as(f32, @floatFromInt(self.height))/2))))
          };

          transformedVertices[j] = finalVertex;
      }
      
      // Draw the polygon
      if(valid) {
          try projectedTriangles.append(projectedTriangle{ .v1 = transformedVertices[0], .v2 = transformedVertices[1], .v3 = transformedVertices[2] });
      }
    }}
    return projectedTriangles.toOwnedSlice();
  }

  pub fn setupCamera(self: Renderer) !zmath.Mat {
    const cx = @cos(-self.cameraRotX);
    const sx = @sin(-self.cameraRotX);
    const cy = @cos(-self.cameraRotY);
    const sy = @sin(-self.cameraRotY);
    const cz = @cos(-self.cameraRotZ);
    const sz = @sin(-self.cameraRotZ);

    const cameraRotXMatrix = zmath.matFromArr([16]f32{
      1,0,0,0,
      0,cx,sx,0,
      0,-sx,cx,0,
      0,0,0,1
    });

    const cameraRotYMatrix = zmath.matFromArr([16]f32{
      cy,0,-sy,0,
      0,1,0,0,
      sy,0,cy,0,
      0,0,0,1
    });

    const cameraRotZMatrix = zmath.matFromArr([16]f32{
      cz,sz,0,0,
      -sz,cz,0,0,
      0,0,1,0,
      0,0,0,1
    });

    const cameraTranslationMatrix = zmath.matFromArr([16]f32{
      1,0,0,0,
      0,1,0,0,
      0,0,1,0,
      -self.cameraPosX,-self.cameraPosY,-self.cameraPosZ,1
    });    

    var viewMatrix = zmath.matFromArr([16]f32{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}); // [1 0 0 0] [0 1 0 0] [0 0 1 0] [0 0 0 1] 
    viewMatrix = zmath.mul(viewMatrix, cameraTranslationMatrix);
    viewMatrix = zmath.mul(viewMatrix, cameraRotZMatrix);
    viewMatrix = zmath.mul(viewMatrix, cameraRotYMatrix);
    viewMatrix = zmath.mul(viewMatrix, cameraRotXMatrix);
    return viewMatrix;
  }

  pub fn setupWorld(self: Renderer) !zmath.Mat {
    const cx = @cos(self.rotX);
    const sx = @sin(self.rotX);
    const cy = @cos(self.rotY);
    const sy = @sin(self.rotY);
    const cz = @cos(self.rotZ);
    const sz = @sin(self.rotZ);

    const rotXMatrix = zmath.matFromArr([16]f32{
      1,0,0,0,
      0,cx,sx,0,
      0,-sx,cx,0,
      0,0,0,1
    });

    const rotYMatrix = zmath.matFromArr([16]f32{
      cy,0,-sy,0,
      0,1,0,0,
      sy,0,cy,0,
      0,0,0,1
    });

    const rotZMatrix = zmath.matFromArr([16]f32{
      cz,sz,0,0,
      -sz,cz,0,0,
      0,0,1,0,
      0,0,0,1
    });

    const translationMatrix = zmath.matFromArr([16]f32{
      1,0,0,0,
      0,1,0,0,
      0,0,1,0,
      -self.posX,-self.posY,-self.posZ,1
    });    

    var worldMatrix = zmath.matFromArr([16]f32{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}); // [1 0 0 0] [0 1 0 0] [0 0 1 0] [0 0 0 1] 
    worldMatrix = zmath.mul(worldMatrix, rotXMatrix);
    worldMatrix = zmath.mul(worldMatrix, rotYMatrix);
    worldMatrix = zmath.mul(worldMatrix, rotZMatrix);
    worldMatrix = zmath.mul(worldMatrix, translationMatrix);
    return worldMatrix;
  }
};

pub const Point2 = struct {
  x: i32,
  y: i32
};

pub const projectedTriangle = struct {
  v1: Point2,
  v2: Point2,
  v3: Point2
};
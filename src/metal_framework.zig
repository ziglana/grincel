const std = @import("std");

pub const MTLSize = extern struct {
    width: u64 align(8),
    height: u64 align(8),
    depth: u64 align(8),
};

pub const MTLRange = extern struct {
    location: usize,
    length: usize,
};

fn mtlsize(w: u32, h: u32, d: u32) MTLSize {
    const width = @as(u64, @intCast(w));
    const height = @as(u64, @intCast(h));
    const depth = @as(u64, @intCast(d));
    return .{ .width = width, .height = height, .depth = depth };
}

pub const MetalFramework = struct {
    device: ?*anyopaque,
    command_queue: ?*anyopaque,

    pub fn init() !MetalFramework {
        std.debug.print("Creating Metal device...\n", .{});
        const device = MTLCreateSystemDefaultDevice() orelse {
            std.debug.print("Failed to create Metal device\n", .{});
            return error.NoMetalDevice;
        };
        std.debug.print("Metal device created\n", .{});

        std.debug.print("Creating command queue...\n", .{});
        const cmd_queue_sel = sel_registerName("newCommandQueue") orelse {
            std.debug.print("Failed to get newCommandQueue selector\n", .{});
            return error.NoCommandQueue;
        };

        const command_queue = objc_msgSend_basic(device, cmd_queue_sel) orelse {
            std.debug.print("Failed to create command queue\n", .{});
            return error.NoCommandQueue;
        };
        std.debug.print("Command queue created\n", .{});

        // Retain both device and command queue since they're autoreleased
        const retain_sel = sel_registerName("retain");
        if (retain_sel != null) {
            _ = objc_msgSend_basic(device, retain_sel);
            _ = objc_msgSend_basic(command_queue, retain_sel);
        }

        return MetalFramework{
            .device = device,
            .command_queue = command_queue,
        };
    }

    pub fn deinit(self: *MetalFramework) void {
        const release_sel = sel_registerName("release");
        if (release_sel) |sel| {
            if (self.command_queue) |queue| {
                _ = objc_msgSend_basic(queue, sel);
                self.command_queue = null;
            }
            if (self.device) |device| {
                _ = objc_msgSend_basic(device, sel);
                self.device = null;
            }
        }
    }

    pub fn is_metal_supported() bool {
        return MTLCreateSystemDefaultDevice() != null;
    }

    pub fn get_device_name(device: ?*anyopaque) ?[*:0]const u8 {
        if (device == null) return null;
        const sel = sel_registerName("name") orelse return null;
        const ns_string = objc_msgSend_basic(device, sel) orelse return null;
        const utf8_sel = sel_registerName("UTF8String") orelse return null;
        const result = objc_msgSend_basic(ns_string, utf8_sel);
        return if (result) |ptr| @ptrCast(ptr) else null;
    }

    pub fn get_max_threadgroup_memory_length(device: ?*anyopaque) u64 {
        if (device == null) return 0;
        const sel = sel_registerName("maxThreadgroupMemoryLength") orelse return 0;
        const result = objc_msgSend_basic(device, sel) orelse return 0;
        // On ARM64, NSUInteger is returned directly in register
        return @as(u64, @intCast(@intFromPtr(result)));
    }

    pub fn get_max_threads_per_threadgroup(device: ?*anyopaque) MTLSize {
        if (device == null) return mtlsize(0, 0, 0);
        const sel = sel_registerName("maxThreadsPerThreadgroup") orelse return mtlsize(0, 0, 0);
        _ = sel; // autofix
        // On Apple Silicon, typical max threads are 1024x1024x1024
        return mtlsize(1024, 1024, 1024);
    }

    pub fn dispatch_compute(encoder: ?*anyopaque, grid_size: MTLSize, threads_per_group_size: MTLSize) void {
        const sel = sel_registerName("dispatchThreadgroups:threadsPerThreadgroup:") orelse return;
        const grid = [_]u32{ @as(u32, @truncate(grid_size.width)), @as(u32, @truncate(grid_size.height)), @as(u32, @truncate(grid_size.depth)) };
        const threads = [_]u32{ @as(u32, @truncate(threads_per_group_size.width)), @as(u32, @truncate(threads_per_group_size.height)), @as(u32, @truncate(threads_per_group_size.depth)) };
        _ = objc_msgSend_dispatch(encoder, sel, &grid, &threads);
    }
};

// Metal resource options
pub const MTLResourceStorageModeShared: u64 = 0;
pub const MTLResourceStorageModeManaged: u64 = 1;
pub const MTLResourceStorageModePrivate: u64 = 2;
pub const MTLResourceStorageModeOptions: u64 = MTLResourceStorageModeShared;

pub const MTLCommandBufferStatus = enum(u32) {
    NotEnqueued = 0,
    Enqueued = 1,
    Committed = 2,
    Scheduled = 3,
    Completed = 4,
    Error = 5,
};

// External function declarations
pub extern fn MTLCreateSystemDefaultDevice() ?*anyopaque;
pub extern fn sel_registerName([*:0]const u8) ?*anyopaque;
pub extern fn objc_getClass([*:0]const u8) ?*anyopaque;
pub extern fn objc_msgSend(?*anyopaque, ?*anyopaque, ...) ?*anyopaque;
pub extern fn objc_msgSend_id_error(?*anyopaque, ?*anyopaque, ?*anyopaque, *?*anyopaque) ?*anyopaque;
pub extern fn NSString_stringWithUTF8String([*:0]const u8) ?*anyopaque;
pub extern fn NSBundle_mainBundle() ?*anyopaque;

// Specialized objc_msgSend for MTLSize return value
pub extern fn objc_msgSend_mtlsize(?*anyopaque, ?*anyopaque) callconv(.C) MTLSize;

// Specialized objc_msgSend for MTLRange parameter
pub fn objc_msgSend_range(obj: ?*anyopaque, sel: ?*anyopaque, range: MTLRange) ?*anyopaque {
    if (obj == null or sel == null) return null;
    return objc_msgSend(obj, sel, range);
}

// Metal function info getters
pub fn MTLFunction_getName(function: ?*anyopaque) ?[*:0]const u8 {
    if (function == null) return null;
    const sel = sel_registerName("name") orelse return null;
    const ns_string = objc_msgSend_basic(function, sel) orelse return null;
    const utf8_sel = sel_registerName("UTF8String") orelse return null;
    const result = objc_msgSend_basic(ns_string, utf8_sel);
    return if (result) |ptr| @ptrCast(ptr) else null;
}

pub fn MTLFunction_getDevice(obj: ?*anyopaque) ?*anyopaque {
    if (obj == null) return null;
    const sel = sel_registerName("device") orelse return null;
    return objc_msgSend_basic(obj, sel);
}

// Wrapper functions
pub fn sel_registerName_wrapper(name: [*:0]const u8) ?*anyopaque {
    const sel = sel_registerName(name) orelse return null;
    std.debug.print("Registered selector '{s}'\n", .{name});
    return sel;
}

pub fn objc_msgSend_basic(obj: ?*anyopaque, sel: ?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null) return null;
    return objc_msgSend(obj, sel);
}

pub fn objc_msgSend_sync_resource(obj: ?*anyopaque, sel: ?*anyopaque, resource: ?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null or resource == null) return null;
    return objc_msgSend(obj, sel, resource);
}

pub fn objc_msgSend_str(obj: ?*anyopaque, sel: ?*anyopaque, str: [*:0]const u8) ?*anyopaque {
    if (obj == null or sel == null) return null;
    return objc_msgSend(obj, sel, str);
}

pub fn objc_msgSend_nsstr(obj: ?*anyopaque, sel: ?*anyopaque, str: ?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null or str == null) return null;
    return objc_msgSend(obj, sel, str);
}

pub fn objc_msgSend_buffer(obj: ?*anyopaque, sel: ?*anyopaque, len: usize, opt: u64) ?*anyopaque {
    if (obj == null or sel == null) return null;
    std.debug.print("Creating buffer with length={}, options={}\n", .{ len, opt });
    const buffer = objc_msgSend(obj, sel, len, opt);
    if (buffer != null) {
        // Retain buffer since it's autoreleased
        const retain_sel = sel_registerName("retain");
        if (retain_sel != null) {
            _ = objc_msgSend_basic(buffer, retain_sel);
            std.debug.print("Buffer retained successfully\n", .{});
        }
        std.debug.print("Buffer created successfully\n", .{});
    } else {
        std.debug.print("Failed to create buffer\n", .{});
    }
    return buffer;
}

pub fn objc_msgSend_buffer_with_bytes(obj: ?*anyopaque, sel: ?*anyopaque, bytes: [*]const u8, len: usize, opt: u64) ?*anyopaque {
    if (obj == null or sel == null) return null;
    std.debug.print("Creating buffer with bytes length={}, options={}\n", .{ len, opt });
    const buffer = objc_msgSend(obj, sel, bytes, len, opt);
    if (buffer != null) {
        // Retain buffer since it's autoreleased
        const retain_sel = sel_registerName("retain");
        if (retain_sel != null) {
            _ = objc_msgSend_basic(buffer, retain_sel);
            std.debug.print("Buffer retained successfully\n", .{});
        }
        std.debug.print("Buffer created successfully\n", .{});
    } else {
        std.debug.print("Failed to create buffer\n", .{});
    }
    return buffer;
}

// Specialized objc_msgSend for setting buffers
pub extern fn objc_msgSend_set_buffer_extern(?*anyopaque, ?*anyopaque, ?*anyopaque, usize, u32) callconv(.C) ?*anyopaque;

pub fn objc_msgSend_set_buffer(obj: ?*anyopaque, sel: ?*anyopaque, buffer: ?*anyopaque, offset: usize, index: u32) ?*anyopaque {
    if (obj == null or sel == null or buffer == null) {
        std.debug.print("Invalid parameters in set_buffer: obj={*}, sel={*}, buffer={*}\n", .{ obj, sel, buffer });
        return null;
    }
    std.debug.print("Setting buffer at index {}: buffer={*}, offset={}\n", .{ index, buffer, offset });
    return objc_msgSend_set_buffer_extern(obj, sel, buffer, offset, index);
}

pub fn objc_msgSend_pipeline(obj: ?*anyopaque, sel: ?*anyopaque, function: ?*anyopaque, err: *?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null or function == null) {
        std.debug.print("Invalid parameters in pipeline creation: obj={*}, sel={*}, function={*}\n", .{ obj, sel, function });
        return null;
    }

    std.debug.print("Creating pipeline state with function: {*}\n", .{function});
    var error_ptr: ?*anyopaque = null;
    const pipeline = objc_msgSend(obj, sel, function, &error_ptr);
    if (pipeline == null and error_ptr != null) {
        err.* = error_ptr;
        std.debug.print("Failed to create pipeline state\n", .{});
    } else if (pipeline != null) {
        // Retain pipeline since it's autoreleased
        const retain_sel = sel_registerName("retain");
        if (retain_sel != null) {
            _ = objc_msgSend_basic(pipeline, retain_sel);
            std.debug.print("Pipeline state retained successfully\n", .{});
        }
        std.debug.print("Pipeline state created successfully\n", .{});
    }
    return pipeline;
}

pub fn objc_msgSend_dispatch(obj: ?*anyopaque, sel: ?*anyopaque, grid: *const [3]u32, group: *const [3]u32) ?*anyopaque {
    if (obj == null or sel == null) return null;
    std.debug.print("Dispatching compute with grid size: ({}, {}, {}), group size: ({}, {}, {})\n", .{
        grid[0],  grid[1],  grid[2],
        group[0], group[1], group[2],
    });
    return objc_msgSend(obj, sel, grid, group);
}

pub fn objc_msgSend_get_status(obj: ?*anyopaque) MTLCommandBufferStatus {
    if (obj == null) return .NotEnqueued;
    const sel = sel_registerName("status") orelse return .NotEnqueued;
    const result = objc_msgSend_basic(obj, sel) orelse return .NotEnqueued;
    const status_int = @intFromPtr(result);
    return @enumFromInt(status_int);
}

pub fn objc_msgSend_url(obj: ?*anyopaque, sel: ?*anyopaque, str: ?*anyopaque, is_dir: bool) ?*anyopaque {
    if (obj == null or sel == null or str == null) return null;
    return objc_msgSend(obj, sel, str, is_dir);
}

pub fn objc_msgSend_library_url(obj: ?*anyopaque, sel: ?*anyopaque, url: ?*anyopaque, err: *?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null or url == null) return null;
    var error_ptr: ?*anyopaque = null;
    const result = objc_msgSend(obj, sel, url, &error_ptr);
    if (result == null and error_ptr != null) {
        err.* = error_ptr;
    } else if (result != null) {
        // Retain library since it's autoreleased
        const retain_sel = sel_registerName("retain");
        if (retain_sel != null) {
            _ = objc_msgSend_basic(result, retain_sel);
            std.debug.print("Library retained successfully\n", .{});
        }
    }
    return result;
}

pub fn objc_msgSend_get_description(obj: ?*anyopaque) ?[*:0]const u8 {
    if (obj == null) return null;
    const sel = sel_registerName("localizedDescription") orelse return null;
    const ns_string = objc_msgSend_basic(obj, sel) orelse return null;
    const utf8_sel = sel_registerName("UTF8String") orelse return null;
    const result = objc_msgSend_basic(ns_string, utf8_sel);
    return if (result) |ptr| @ptrCast(ptr) else null;
}

pub fn objc_msgSend_error(obj: ?*anyopaque, sel: ?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null) return null;
    return objc_msgSend_basic(obj, sel);
}

pub fn objc_msgSend_set_state(obj: ?*anyopaque, sel: ?*anyopaque, state: ?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null or state == null) return null;
    return objc_msgSend(obj, sel, state);
}

pub fn objc_msgSend_function(obj: ?*anyopaque, sel: ?*anyopaque, function: ?*anyopaque) ?*anyopaque {
    if (obj == null or sel == null or function == null) return null;
    return objc_msgSend(obj, sel, function);
}

pub fn objc_msgSend_sync_buffer(obj: ?*anyopaque, sel: ?*anyopaque, range: MTLRange) ?*anyopaque {
    if (obj == null or sel == null) return null;
    return objc_msgSend(obj, sel, range);
}

pub fn objc_msgSend_length(obj: ?*anyopaque, sel: ?*anyopaque) usize {
    if (obj == null or sel == null) return 0;
    const result = objc_msgSend_basic(obj, sel);
    return if (result != null) @intFromPtr(result) else 0;
}

const std = @import("std");

pub const MetalFramework = struct {
    pub fn new_default_library(self: *const MetalFramework, device: Device) ?Library {
        _ = self;
        const sel = sel_registerName("newDefaultLibrary");
        return @ptrCast(objc_msgSend(device, sel));
    }

    pub const Device = *anyopaque;
    pub const CommandQueue = *anyopaque;
    pub const CommandBuffer = *anyopaque;
    pub const ComputeCommandEncoder = *anyopaque;
    pub const Library = *anyopaque;
    pub const Function = *anyopaque;
    pub const ComputePipelineState = *anyopaque;
    pub const Buffer = *anyopaque;
    pub const Error = **anyopaque;

    pub const Size = extern struct {
        width: usize,
        height: usize,
        depth: usize,
    };

    pub const ResourceOptions = packed struct(u32) {
        storage_mode: u2 = 0,
        cpu_cache_mode: u2 = 0,
        _padding: u28 = 0,
    };

    // Function types
    pub const CreateSystemDefaultDeviceFn = *const fn () callconv(.C) ?Device;
    pub const NewCommandQueueFn = *const fn (Device) callconv(.C) ?CommandQueue;
    pub const NewBufferWithLengthFn = *const fn (Device, usize, ResourceOptions) callconv(.C) ?Buffer;
    pub const CommandBufferFn = *const fn (CommandQueue) callconv(.C) ?CommandBuffer;
    pub const ComputeCommandEncoderFn = *const fn (CommandBuffer) callconv(.C) ?ComputeCommandEncoder;
    pub const SetComputePipelineStateFn = *const fn (ComputeCommandEncoder, ComputePipelineState) callconv(.C) void;
    pub const SetBufferFn = *const fn (ComputeCommandEncoder, Buffer, usize, u32) callconv(.C) void;
    pub const DispatchThreadgroupsFn = *const fn (ComputeCommandEncoder, Size, Size) callconv(.C) void;
    pub const EndEncodingFn = *const fn (ComputeCommandEncoder) callconv(.C) void;
    pub const CommitFn = *const fn (CommandBuffer) callconv(.C) void;
    pub const WaitUntilCompletedFn = *const fn (CommandBuffer) callconv(.C) void;
    pub const GetContentsFn = *const fn (Buffer) callconv(.C) [*]u8;
    pub const GetLengthFn = *const fn (Buffer) callconv(.C) usize;
    pub const NewLibraryWithDataFn = *const fn (Device, [*]const u8, usize, ?**anyopaque) callconv(.C) ?Library;
    pub const NewLibraryWithFileFn = *const fn (Device, [*:0]const u8, ?**anyopaque) callconv(.C) ?Library;
    pub const NewFunctionWithNameFn = *const fn (Library, [*:0]const u8) callconv(.C) ?Function;
    pub const NewComputePipelineStateFn = *const fn (Device, Function, ?**anyopaque) callconv(.C) ?ComputePipelineState;

    // Function pointers
    create_system_default_device: CreateSystemDefaultDeviceFn,
    new_command_queue: NewCommandQueueFn,
    new_buffer_with_length: NewBufferWithLengthFn,
    command_buffer: CommandBufferFn,
    compute_command_encoder: ComputeCommandEncoderFn,
    set_compute_pipeline_state: SetComputePipelineStateFn,
    set_buffer: SetBufferFn,
    dispatch_threadgroups: DispatchThreadgroupsFn,
    end_encoding: EndEncodingFn,
    commit: CommitFn,
    wait_until_completed: WaitUntilCompletedFn,
    get_contents: GetContentsFn,
    get_length: GetLengthFn,
    new_library_with_data: NewLibraryWithDataFn,
    new_library_with_file: NewLibraryWithFileFn,
    new_function_with_name: NewFunctionWithNameFn,
    new_compute_pipeline_state: NewComputePipelineStateFn,

    // Objective-C runtime functions
    pub extern "objc" fn objc_getClass(name: [*:0]const u8) ?*anyopaque;
    pub extern "objc" fn sel_registerName(name: [*:0]const u8) *anyopaque;
    pub extern "objc" fn objc_msgSend(obj: ?*anyopaque, sel: *anyopaque, ...) callconv(.C) ?*anyopaque;

    pub fn init() !MetalFramework {
        // Create function pointers
        // Initialize Foundation framework
        const NSAutoreleasePool = objc_getClass("NSAutoreleasePool") orelse return error.NoFoundation;
        const pool = objc_msgSend(objc_msgSend(NSAutoreleasePool, sel_registerName("alloc")), sel_registerName("init")) orelse return error.NoFoundation;
        defer _ = objc_msgSend(pool, sel_registerName("drain"));

        // Initialize Metal framework
        const MTLCreateSystemDefaultDevice = @extern(*const fn () callconv(.C) ?Device, .{ .name = "MTLCreateSystemDefaultDevice", .linkage = .strong });
        
        return MetalFramework{
            .create_system_default_device = struct {
                fn func() callconv(.C) ?Device {
                    return MTLCreateSystemDefaultDevice();
                }
            }.func,
            .new_command_queue = struct {
                fn func(dev: Device) callconv(.C) ?CommandQueue {
                    const sel = sel_registerName("newCommandQueue");
                    return objc_msgSend(dev, sel);
                }
            }.func,
            .new_buffer_with_length = struct {
                fn func(dev: Device, length: usize, options: ResourceOptions) callconv(.C) ?Buffer {
                    const sel = sel_registerName("newBufferWithLength:options:");
                    return objc_msgSend(dev, sel, length, @as(c_uint, @bitCast(options)));
                }
            }.func,
            .command_buffer = struct {
                fn func(queue: CommandQueue) callconv(.C) ?CommandBuffer {
                    const sel = sel_registerName("commandBuffer");
                    return objc_msgSend(queue, sel);
                }
            }.func,
            .compute_command_encoder = struct {
                fn func(buffer: CommandBuffer) callconv(.C) ?ComputeCommandEncoder {
                    const sel = sel_registerName("computeCommandEncoder");
                    return objc_msgSend(buffer, sel);
                }
            }.func,
            .set_compute_pipeline_state = struct {
                fn func(encoder: ComputeCommandEncoder, state: ComputePipelineState) callconv(.C) void {
                    const sel = sel_registerName("setPipelineState:");
                    _ = objc_msgSend(encoder, sel, state);
                }
            }.func,
            .set_buffer = struct {
                fn func(encoder: ComputeCommandEncoder, buffer: Buffer, offset: usize, index: u32) callconv(.C) void {
                    const sel = sel_registerName("setBuffer:offset:atIndex:");
                    _ = objc_msgSend(encoder, sel, buffer, offset, index);
                }
            }.func,
            .dispatch_threadgroups = struct {
                fn func(encoder: ComputeCommandEncoder, grid: Size, group: Size) callconv(.C) void {
                    const sel = sel_registerName("dispatchThreadgroups:threadsPerThreadgroup:");
                    _ = objc_msgSend(encoder, sel, grid, group);
                }
            }.func,
            .end_encoding = struct {
                fn func(encoder: ComputeCommandEncoder) callconv(.C) void {
                    const sel = sel_registerName("endEncoding");
                    _ = objc_msgSend(encoder, sel);
                }
            }.func,
            .commit = struct {
                fn func(buffer: CommandBuffer) callconv(.C) void {
                    const sel = sel_registerName("commit");
                    _ = objc_msgSend(buffer, sel);
                }
            }.func,
            .wait_until_completed = struct {
                fn func(buffer: CommandBuffer) callconv(.C) void {
                    const sel = sel_registerName("waitUntilCompleted");
                    _ = objc_msgSend(buffer, sel);
                }
            }.func,
            .get_contents = struct {
                fn func(buffer: Buffer) callconv(.C) [*]u8 {
                    const sel = sel_registerName("contents");
                    return @ptrCast(objc_msgSend(buffer, sel) orelse unreachable);
                }
            }.func,
            .get_length = struct {
                fn func(buffer: Buffer) callconv(.C) usize {
                    const sel = sel_registerName("length");
                    const ptr = objc_msgSend(buffer, sel) orelse unreachable;
                    return @intFromPtr(ptr);
                }
            }.func,
            .new_library_with_data = struct {
                fn func(dev: Device, data: [*]const u8, len: usize, err: ?**anyopaque) callconv(.C) ?Library {
                    const lib_sel = sel_registerName("newLibraryWithSource:options:error:");
                    const NSString = objc_getClass("NSString") orelse return null;
                    const str_sel = sel_registerName("stringWithUTF8String:");
                    const source = objc_msgSend(NSString, str_sel, @as([*:0]const u8, @ptrCast(data[0..len]))) orelse return null;
                    const MTLCompileOptions = objc_getClass("MTLCompileOptions") orelse return null;
                    const alloc_sel = sel_registerName("alloc");
                    const init_sel = sel_registerName("init");
                    const options = objc_msgSend(objc_msgSend(MTLCompileOptions, alloc_sel), init_sel) orelse return null;
                    const lang_sel = sel_registerName("setLanguageVersion:");
                    _ = objc_msgSend(options, lang_sel, @as(c_uint, 3)); // Metal 3.0
                    return objc_msgSend(dev, lib_sel, source, options, err);
                }
            }.func,
            .new_function_with_name = struct {
                fn func(lib: Library, name: [*:0]const u8) callconv(.C) ?Function {
                    const func_sel = sel_registerName("newFunctionWithName:");
                    const NSString = objc_getClass("NSString") orelse return null;
                    const str_sel = sel_registerName("stringWithUTF8String:");
                    const func_name = objc_msgSend(NSString, str_sel, name) orelse return null;
                    return objc_msgSend(lib, func_sel, func_name);
                }
            }.func,
            .new_library_with_file = struct {
                fn func(dev: Device, path: [*:0]const u8, err: ?**anyopaque) callconv(.C) ?Library {
                    const sel = sel_registerName("newLibraryWithFile:error:");
                    const NSString = objc_getClass("NSString") orelse return null;
                    const str_sel = sel_registerName("stringWithUTF8String:");
                    const file_path = objc_msgSend(NSString, str_sel, path) orelse return null;
                    return objc_msgSend(dev, sel, file_path, err);
                }
            }.func,
            .new_compute_pipeline_state = struct {
                fn func(dev: Device, function: Function, err: ?**anyopaque) callconv(.C) ?ComputePipelineState {
                    const sel = sel_registerName("newComputePipelineStateWithFunction:error:");
                    return objc_msgSend(dev, sel, function, err);
                }
            }.func,
        };
    }
};

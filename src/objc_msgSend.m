#import <objc/runtime.h>
#import <objc/message.h>
#import <Metal/Metal.h>
#import <Foundation/Foundation.h>

// Objective-C runtime wrappers
void* objc_getClass_wrapper(const char* name) {
    return (__bridge void*)objc_getClass(name);
}

SEL sel_registerName_wrapper(const char* name) {
    return sel_registerName(name);
}

void* objc_msgSend_basic(void* obj, SEL sel) {
    if (obj == nil || sel == nil) return nil;
    return (__bridge void*)((id (*)(id, SEL))objc_msgSend)((__bridge id)obj, sel);
}

void* objc_msgSend_str(void* obj, SEL sel, const char* str) {
    if (obj == nil || sel == nil || str == nil) return nil;
    NSString* nsstr = [NSString stringWithUTF8String:str];
    return (__bridge void*)((id (*)(id, SEL, id))objc_msgSend)((__bridge id)obj, sel, nsstr);
}

void* objc_msgSend_str_bool(void* obj, SEL sel, const char* str, bool value) {
    if (obj == nil || sel == nil || str == nil) return nil;
    NSString* nsstr = [NSString stringWithUTF8String:str];
    return (__bridge void*)((id (*)(id, SEL, id, BOOL))objc_msgSend)((__bridge id)obj, sel, nsstr, value);
}

void* objc_msgSend_id_error(void* obj, SEL sel, void* arg, void** error) {
    if (obj == nil || sel == nil || arg == nil) return nil;
    NSError* __autoreleasing err = nil;
    id result = ((id (*)(id, SEL, id, NSError**))objc_msgSend)((__bridge id)obj, sel, (__bridge id)arg, &err);
    if (err) {
        *error = (void*)CFBridgingRetain(err);
        return NULL;
    }
    return (__bridge void*)result;
}

void* objc_msgSend_function(void* obj, SEL sel, void* function) {
    if (obj == nil || sel == nil || function == nil) return nil;
    return (__bridge void*)((id (*)(id, SEL, id))objc_msgSend)((__bridge id)obj, sel, (__bridge id)function);
}

void* objc_msgSend_id_index(void* obj, SEL sel, uint32_t index) {
    if (obj == nil || sel == nil) return nil;
    return (__bridge void*)((id (*)(id, SEL, NSUInteger))objc_msgSend)((__bridge id)obj, sel, index);
}

bool objc_msgSend_bool(void* obj, SEL sel, void* arg) {
    if (obj == nil || sel == nil || arg == nil) return false;
    return ((BOOL (*)(id, SEL, id))objc_msgSend)((__bridge id)obj, sel, (__bridge id)arg);
}

void* objc_msgSend_buffer(void* obj, SEL sel, uint64_t length, uint64_t options) {
    if (obj == nil || sel == nil) return nil;
    
    @autoreleasepool {
        id<MTLDevice> device = (__bridge id<MTLDevice>)obj;
        id<MTLBuffer> buffer = [device newBufferWithLength:length options:options];
        
        if (buffer) {
            NSLog(@"Created buffer: %@, length=%llu, options=%llu", buffer, length, options);
            NSLog(@"Buffer contents: %p", [buffer contents]);
            return (void*)CFBridgingRetain(buffer);
        } else {
            NSLog(@"Failed to create buffer");
            return nil;
        }
    }
}

void* objc_msgSend_set_buffer(void* obj, SEL sel, void* buffer, uint64_t offset, uint64_t index) {
    if (obj == nil || sel == nil || buffer == nil) {
        NSLog(@"Invalid parameters: obj=%p, sel=%p, buffer=%p", obj, sel, buffer);
        return nil;
    }
    
    @autoreleasepool {
        @try {
            id<MTLComputeCommandEncoder> encoder = (__bridge id<MTLComputeCommandEncoder>)obj;
            id<MTLBuffer> mtlBuffer = (__bridge id<MTLBuffer>)buffer;
            
            NSLog(@"Setting buffer at index %llu: %@, offset=%llu", index, mtlBuffer, offset);
            NSLog(@"Buffer contents: %p", [mtlBuffer contents]);
            
            [encoder setBuffer:mtlBuffer offset:offset atIndex:index];
            
            NSLog(@"Successfully set buffer");
            return (__bridge void*)encoder;
        } @catch (NSException* exception) {
            NSLog(@"Exception setting buffer: %@", exception);
            return nil;
        }
    }
}

void* objc_msgSend_pipeline(void* obj, SEL sel, void* function, void** error) {
    if (obj == nil || sel == nil || function == nil) {
        NSLog(@"Invalid parameters in pipeline creation: obj=%p, sel=%p, function=%p", obj, sel, function);
        return nil;
    }
    
    @autoreleasepool {
        @try {
            id<MTLDevice> device = (__bridge id<MTLDevice>)obj;
            id<MTLFunction> mtlFunction = (__bridge id<MTLFunction>)function;
            
            NSLog(@"Creating pipeline state with function: %@", mtlFunction);
            NSLog(@"Function name: %@", [mtlFunction name]);
            NSLog(@"Function device: %@", [mtlFunction device]);
            
            NSError* __autoreleasing err = nil;
            id<MTLComputePipelineState> pipeline = nil;
            
            @try {
                pipeline = [device newComputePipelineStateWithFunction:mtlFunction error:&err];
                if (pipeline) {
                    NSLog(@"Successfully created pipeline state: %@", pipeline);
                    // Return a retained pipeline state
                    return (void*)CFBridgingRetain(pipeline);
                } else {
                    NSLog(@"Failed to create pipeline state");
                    if (err) {
                        NSLog(@"Error: %@", err);
                        *error = (void*)CFBridgingRetain(err);
                    }
                    return nil;
                }
            } @catch (NSException* exception) {
                NSLog(@"Exception creating pipeline: %@", exception);
                NSLog(@"Exception name: %@", [exception name]);
                NSLog(@"Exception reason: %@", [exception reason]);
                NSLog(@"Exception userInfo: %@", [exception userInfo]);
                NSLog(@"Exception callStackSymbols: %@", [exception callStackSymbols]);
                return nil;
            }
        } @catch (NSException* exception) {
            NSLog(@"Exception in pipeline creation: %@", exception);
            NSLog(@"Exception name: %@", [exception name]);
            NSLog(@"Exception reason: %@", [exception reason]);
            NSLog(@"Exception userInfo: %@", [exception userInfo]);
            NSLog(@"Exception callStackSymbols: %@", [exception callStackSymbols]);
            return nil;
        }
    }
}

void* objc_msgSend_dispatch(void* obj, SEL sel, const void* grid_size, const void* group_size) {
    if (obj == nil || sel == nil || grid_size == nil || group_size == nil) return nil;
    
    @autoreleasepool {
        MTLSize grid = *(MTLSize*)grid_size;
        MTLSize group = *(MTLSize*)group_size;
        
        NSLog(@"Dispatching compute with grid size: (%llu, %llu, %llu), group size: (%llu, %llu, %llu)",
              (unsigned long long)grid.width, (unsigned long long)grid.height, (unsigned long long)grid.depth,
              (unsigned long long)group.width, (unsigned long long)group.height, (unsigned long long)group.depth);
        
        id<MTLComputeCommandEncoder> encoder = (__bridge id<MTLComputeCommandEncoder>)obj;
        [encoder dispatchThreadgroups:grid threadsPerThreadgroup:group];
        
        return (__bridge void*)encoder;
    }
}

// Metal framework wrappers
void* MTLCreateSystemDefaultDevice_wrapper(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSLog(@"Created Metal device: %@", device);
    return (void*)CFBridgingRetain(device);
}

// Foundation framework wrappers
void* NSString_stringWithUTF8String(const char* str) {
    if (str == nil) return nil;
    return (void*)CFBridgingRetain([NSString stringWithUTF8String:str]);
}

void* NSBundle_mainBundle(void) {
    return (void*)CFBridgingRetain([NSBundle mainBundle]);
}

// Function to get function name from MTLFunction
const char* MTLFunction_getName(void* function) {
    if (function == nil) return nil;
    id<MTLFunction> mtlFunction = (__bridge id<MTLFunction>)function;
    return [[mtlFunction name] UTF8String];
}

// Function to get device from MTLFunction
void* MTLFunction_getDevice(void* function) {
    if (function == nil) return nil;
    id<MTLFunction> mtlFunction = (__bridge id<MTLFunction>)function;
    return (__bridge void*)[mtlFunction device];
}

// Function to get description from NSError
void* objc_msgSend_get_description(void* obj) {
    if (obj == nil) return nil;
    NSError* error = (__bridge NSError*)obj;
    return (void*)CFBridgingRetain([error localizedDescription]);
}

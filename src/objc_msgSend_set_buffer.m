#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

void* objc_msgSend_set_buffer_extern(id obj, SEL sel, id buffer, NSUInteger offset, NSUInteger index) {
    [obj setBuffer:buffer offset:offset atIndex:index];
    return obj; // Return the encoder object itself
}

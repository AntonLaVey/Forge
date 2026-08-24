#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <substrate.h>

void (*old_OnCreateSteppingStonesRunResponse)(void* instance, void* response_obj, void* method_info);

void new_OnCreateSteppingStonesRunResponse(void* instance, void* response_obj, void* method_info) {
    old_OnCreateSteppingStonesRunResponse(instance, response_obj, method_info);
    if (response_obj != NULL) {
        uint64_t raw_seed = *(uint64_t*)((uint64_t)response_obj + 0x18);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Seed Captured!"
                                                                           message:[NSString stringWithFormat:@"Raw seed: %llu", raw_seed]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    }
}

__attribute__((constructor)) void setup_hook() {
    uint64_t base_address = _dyld_get_image_vmaddr_slide(0); 
    MSHookFunction((void*)(base_address + 0x5066F14), (void*)new_OnCreateSteppingStonesRunResponse, (void**)&old_OnCreateSteppingStonesRunResponse);[cite: 1]
}

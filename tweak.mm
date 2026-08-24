#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import "substrate.h"

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

static void image_loaded(const struct mach_header *mhp, intptr_t vmaddr_slide) {
    Dl_info info;
    if (dladdr(mhp, &info) && info.dli_fname) {
        NSString *path = [NSString stringWithUTF8String:info.dli_fname];
        
        BOOL isAppBundle = [path rangeOfString:@".app/"].location != NSNotFound;
        BOOL isPlugin = [path rangeOfString:@".app/PlugIns/"].location != NSNotFound;
        
        if (isAppBundle && !isPlugin) {
            static bool hasHooked = false;
            if (!hasHooked) {
                void *target_address = (void*)(vmaddr_slide + 0x5066F14);
                MSHookFunction(target_address, (void*)new_OnCreateSteppingStonesRunResponse, (void**)&old_OnCreateSteppingStonesRunResponse);
                hasHooked = true;
            }
        }
    }
}

__attribute__((constructor)) void setup_hook() {
    _dyld_register_func_for_add_image(image_loaded);
}

#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#include "substrate.h"

// IL2CPP function pointer definition
void (*old_OnCreateSteppingStonesRunResponse)(void* __this, void* response_obj, void* method_info);

void new_OnCreateSteppingStonesRunResponse(void* __this, void* response_obj, void* method_info) {
    // Safely call the original method first
    old_OnCreateSteppingStonesRunResponse(__this, response_obj, method_info);
    
    // Guard against null pointers to prevent crashes
    if (response_obj != NULL) {
        @try {
            // Read the seed at +0x18 (ensure this memory is readable)
            uint64_t raw_seed = *(uint64_t*)((uint64_t)response_obj + 0x18);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Seed Captured!"
                                                                               message:[NSString stringWithFormat:@"Raw seed: %llu", raw_seed]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil]];
                
                // Safe window root presentation
                UIWindow *keyWindow = nil;
                for (UIWindow *window in [UIApplication sharedApplication].windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
                [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            });
        } @catch (NSException *exception) {
            // Catch any bad memory reads so the game doesn't crash
            NSLog(@"[SeedCatcher] Exception caught during seed read: %@", exception.reason);
        }
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
                // IL2CPP base address calculation + RVA offset
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

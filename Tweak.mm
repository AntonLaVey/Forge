#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>
#include "substrate.h"

// IL2CPP function pointer definition
void (*old_OnCreateSteppingStonesRunResponse)(void* __this, void* response_obj, void* method_info);

// Safely read `size` bytes from `address`. An Objective-C @try/@catch cannot
// trap an invalid memory access (that raises EXC_BAD_ACCESS / SIGSEGV, not an
// NSException), so we go through the Mach VM API, which returns an error code
// instead of faulting the whole process on a bad pointer.
static bool safe_read(vm_address_t address, void *out, vm_size_t size) {
    vm_size_t read_count = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(),
                                         address,
                                         size,
                                         (vm_address_t)out,
                                         &read_count);
    return kr == KERN_SUCCESS && read_count == size;
}

// Resolve a usable key window via the scene API (the old
// `[UIApplication sharedApplication].windows` / keyWindow path is deprecated and
// can return nil), falling back to the first available window if none is key.
static UIWindow *active_key_window(void) {
    UIWindow *fallback = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
            if (fallback == nil) fallback = window;
        }
    }
    return fallback;
}

void new_OnCreateSteppingStonesRunResponse(void* __this, void* response_obj, void* method_info) {
    // Safely call the original method first
    old_OnCreateSteppingStonesRunResponse(__this, response_obj, method_info);

    // Guard against a null base before touching the response object.
    if (response_obj == NULL) return;

    // Read the seed at +0x18 without risking a hard crash on an invalid pointer.
    uint64_t raw_seed = 0;
    if (!safe_read((vm_address_t)((uintptr_t)response_obj + 0x18), &raw_seed, sizeof(raw_seed))) {
        NSLog(@"[SeedCatcher] Failed to read seed at response_obj+0x18");
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        // The main queue is serial, so this flag is only ever touched here.
        static BOOL isPresenting = NO;
        if (isPresenting) return;   // don't stack alerts / present while presenting

        UIWindow *keyWindow = active_key_window();
        UIViewController *root = keyWindow.rootViewController;
        // Present above whatever is already on screen.
        while (root.presentedViewController) root = root.presentedViewController;
        if (root == nil) return;

        isPresenting = YES;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Seed Captured!"
                                                                       message:[NSString stringWithFormat:@"Raw seed: %llu", raw_seed]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
            isPresenting = NO;
        }]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

static void image_loaded(const struct mach_header *mhp, intptr_t vmaddr_slide) {
    // Only hook against the main executable. The RVA below is relative to that
    // binary's load address, so the slide we add it to must come from the same
    // image; matching "any app-bundle, non-plugin image" could latch onto a
    // framework and apply the offset to the wrong base. If the target function
    // actually lives in a framework, match that framework's name here instead.
    if (mhp->filetype != MH_EXECUTE) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // IL2CPP base address (executable slide) + RVA offset
        void *target_address = (void*)(vmaddr_slide + 0x5066F14);
        MSHookFunction(target_address,
                       (void*)new_OnCreateSteppingStonesRunResponse,
                       (void**)&old_OnCreateSteppingStonesRunResponse);
    });
}

__attribute__((constructor)) void setup_hook() {
    _dyld_register_func_for_add_image(image_loaded);
}

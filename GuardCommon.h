#ifndef IKP_GUARD_COMMON_H
#define IKP_GUARD_COMMON_H

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <string.h>
#import "IKPIntegrity.h"

#define IKP_PIRACY_OVERLAY_TAG 0x4B495241

typedef int         (*IKPProtocolFn)(void);
typedef const char *(*IKPStringFn)(void);
typedef int         (*IKPCheckFn)(void);

static BOOL IKPGuardExactImageLoaded(const char *basename, const char **outFullPath, const struct mach_header **outHeader) {
    if (!basename) return NO;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *path = _dyld_get_image_name(i);
        if (!path) continue;
        const char *slash = strrchr(path, '/');
        const char *name = slash ? slash + 1 : path;
        if (strcmp(name, basename) == 0) {
            if (outFullPath) *outFullPath = path;
            if (outHeader) *outHeader = _dyld_get_image_header(i);
            return YES;
        }
    }
    return NO;
}

static BOOL IKPGuardSymbolBelongsToProtectedImage(void *symbol, const struct mach_header *protectedHeader) {
    if (!symbol || !protectedHeader) return NO;
    Dl_info info = {0};
    if (dladdr(symbol, &info) == 0 || !info.dli_fname || !info.dli_fbase) return NO;
    const char *slash = strrchr(info.dli_fname, '/');
    const char *name = slash ? slash + 1 : info.dli_fname;
    return strcmp(name, IKP_EXPECTED_DYLIB_NAME_C) == 0 && info.dli_fbase == (const void *)protectedHeader;
}

static BOOL IKPGuardCStringEquals(const char *actual, const char *expected) {
    return actual && expected && strcmp(actual, expected) == 0;
}

static BOOL IKPGuardVerifyProtectedDylib(NSString **reasonOut) {
    const char *protectedPath = NULL;
    const struct mach_header *protectedHeader = NULL;
    if (!IKPGuardExactImageLoaded(IKP_EXPECTED_DYLIB_NAME_C, &protectedPath, &protectedHeader)) {
        if (reasonOut) *reasonOut = @"protected dylib missing";
        return NO;
    }

    // Every guard protects every other guard. Removing a single guard trips all survivors.
    for (size_t i = 0; i < IKP_EXPECTED_GUARD_COUNT; i++) {
        if (!IKPGuardExactImageLoaded(IKP_EXPECTED_GUARDS[i], NULL, NULL)) {
            if (reasonOut) *reasonOut = [NSString stringWithFormat:@"guard missing: %s", IKP_EXPECTED_GUARDS[i]];
            return NO;
        }
    }

    IKPProtocolFn protocolFn = (IKPProtocolFn)dlsym(RTLD_DEFAULT, "IKPIntegrityProtocolVersion");
    IKPStringFn brandFn      = (IKPStringFn)dlsym(RTLD_DEFAULT, "IKPIntegrityBrand");
    IKPStringFn telegramFn   = (IKPStringFn)dlsym(RTLD_DEFAULT, "IKPIntegrityTelegramURL");
    IKPStringFn developerFn  = (IKPStringFn)dlsym(RTLD_DEFAULT, "IKPIntegrityDeveloperURL");
    IKPStringFn titleFn      = (IKPStringFn)dlsym(RTLD_DEFAULT, "IKPIntegrityTitle");
    IKPStringFn subtitleFn   = (IKPStringFn)dlsym(RTLD_DEFAULT, "IKPIntegritySubtitle");
    IKPStringFn logoHashFn   = (IKPStringFn)dlsym(RTLD_DEFAULT, "IKPIntegrityLogoSHA256");
    IKPCheckFn selfCheckFn   = (IKPCheckFn)dlsym(RTLD_DEFAULT, "IKPIntegritySelfCheck");
    IKPCheckFn uiCheckFn     = (IKPCheckFn)dlsym(RTLD_DEFAULT, "IKPIntegrityUICheck");

    void *symbols[] = {
        (void *)protocolFn, (void *)brandFn, (void *)telegramFn, (void *)developerFn,
        (void *)titleFn, (void *)subtitleFn, (void *)logoHashFn, (void *)selfCheckFn, (void *)uiCheckFn
    };
    for (size_t i = 0; i < sizeof(symbols)/sizeof(symbols[0]); i++) {
        if (!IKPGuardSymbolBelongsToProtectedImage(symbols[i], protectedHeader)) {
            if (reasonOut) *reasonOut = @"integrity symbol missing or spoofed";
            return NO;
        }
    }

    if (protocolFn() != IKP_INTEGRITY_PROTOCOL) {
        if (reasonOut) *reasonOut = @"integrity protocol mismatch";
        return NO;
    }
    if (!IKPGuardCStringEquals(brandFn(), IKP_EXPECTED_BRAND_C)) {
        if (reasonOut) *reasonOut = @"brand modified";
        return NO;
    }
    if (!IKPGuardCStringEquals(telegramFn(), IKP_EXPECTED_TELEGRAM_C)) {
        if (reasonOut) *reasonOut = @"telegram link modified";
        return NO;
    }
    if (!IKPGuardCStringEquals(developerFn(), IKP_EXPECTED_DEVELOPER_C)) {
        if (reasonOut) *reasonOut = @"developer link modified";
        return NO;
    }
    if (!IKPGuardCStringEquals(titleFn(), IKP_EXPECTED_UI_TITLE_C)) {
        if (reasonOut) *reasonOut = @"title modified";
        return NO;
    }
    if (!IKPGuardCStringEquals(subtitleFn(), IKP_EXPECTED_SUBTITLE_C)) {
        if (reasonOut) *reasonOut = @"subtitle modified";
        return NO;
    }
    if (!IKPGuardCStringEquals(logoHashFn(), IKP_EXPECTED_LOGO_SHA256_C)) {
        if (reasonOut) *reasonOut = @"logo fingerprint modified";
        return NO;
    }
    if (selfCheckFn() != 1) {
        if (reasonOut) *reasonOut = @"iKiraPlus internal self-check failed";
        return NO;
    }
    if (uiCheckFn() != 1) {
        if (reasonOut) *reasonOut = @"visible iKiraPlus UI modified";
        return NO;
    }

    return YES;
}

static UIWindow *IKPGuardFindWindow(void) {
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *rawScene in [UIApplication sharedApplication].connectedScenes) {
            if (![rawScene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *scene = (UIWindowScene *)rawScene;
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow) return w;
                if (!window && !w.hidden && w.alpha > 0.0) window = w;
            }
        }
    }
    if (!window) window = [[[UIApplication sharedApplication] windows] firstObject];
    return window;
}

static void IKPGuardShowViolation(NSString *guardName, NSString *reason) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = IKPGuardFindWindow();
        if (!window) {
            // Never fail open just because the app has not created a window yet.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ IKPGuardShowViolation(guardName, reason); });
            return;
        }
        if ([window viewWithTag:IKP_PIRACY_OVERLAY_TAG]) return;

        NSLog(@"[iKiraPlus:%@] integrity violation: %@", guardName, reason ?: @"unknown");

        UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
        overlay.tag = IKP_PIRACY_OVERLAY_TAG;
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlay.backgroundColor = [UIColor colorWithRed:0.05 green:0.0 blue:0.0 alpha:0.985];
        [window addSubview:overlay];
        [window bringSubviewToFront:overlay];

        UILabel *icon = [UILabel new];
        icon.text = @"⛔️";
        icon.font = [UIFont systemFontOfSize:66];
        icon.textAlignment = NSTextAlignmentCenter;
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        [overlay addSubview:icon];

        UILabel *title = [UILabel new];
        title.text = @"⚠️ تم اكتشاف تلاعب بـ iKiraPlus ⚠️";
        title.textColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:1];
        title.font = [UIFont boldSystemFontOfSize:21];
        title.textAlignment = NSTextAlignmentCenter;
        title.numberOfLines = 0;
        title.translatesAutoresizingMaskIntoConstraints = NO;
        [overlay addSubview:title];

        UILabel *msg = [UILabel new];
        msg.text = @"هذا التطبيق مسروق الحقوق او التعديل من قناة ( كيرا بلس - @ikiraplus ) الرجاء عدم حذف حقوقنا من التطبيق واحترام الجهد المبذول";
        msg.textColor = [UIColor colorWithWhite:0.86 alpha:1];
        msg.font = [UIFont systemFontOfSize:14];
        msg.textAlignment = NSTextAlignmentCenter;
        msg.numberOfLines = 0;
        msg.translatesAutoresizingMaskIntoConstraints = NO;
        [overlay addSubview:msg];

        UILabel *counter = [UILabel new];
        counter.text = @"سيتم إغلاق التطبيق خلال 10 ثواني...";
        counter.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1];
        counter.font = [UIFont boldSystemFontOfSize:15];
        counter.textAlignment = NSTextAlignmentCenter;
        counter.translatesAutoresizingMaskIntoConstraints = NO;
        [overlay addSubview:counter];

        UILayoutGuide *safe = overlay.safeAreaLayoutGuide;
        [NSLayoutConstraint activateConstraints:@[
            [icon.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
            [icon.topAnchor constraintGreaterThanOrEqualToAnchor:safe.topAnchor constant:35],
            [title.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
            [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
            [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:safe.leadingAnchor constant:20],
            [title.trailingAnchor constraintLessThanOrEqualToAnchor:safe.trailingAnchor constant:-20],
            [msg.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
            [msg.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:18],
            [msg.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
            [msg.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
            [counter.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
            [counter.topAnchor constraintEqualToAnchor:msg.bottomAnchor constant:24],
            [counter.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-25]
        ]];

        overlay.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{ overlay.alpha = 1.0; }];

        __block int seconds = 10;
        NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            seconds--;
            if (seconds > 0) {
                counter.text = [NSString stringWithFormat:@"سيتم إغلاق التطبيق خلال %d ثواني...", seconds];
            } else {
                [t invalidate];
                abort();
            }
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

static void IKPGuardRunCheck(NSString *guardName) {
    @try {
        NSString *reason = nil;
        if (!IKPGuardVerifyProtectedDylib(&reason)) {
            IKPGuardShowViolation(guardName, reason);
        }
    } @catch (NSException *e) {
        IKPGuardShowViolation(guardName, [NSString stringWithFormat:@"guard exception: %@", e.name]);
    }
}

static void IKPGuardInstall(NSString *guardName, uint32_t initialDelayMs) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(initialDelayMs * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{ IKPGuardRunCheck(guardName); });

    // A second independent pass catches delayed hooks/patches after launch.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((initialDelayMs + 5500) * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{ IKPGuardRunCheck(guardName); });

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(__unused NSNotification *note) {
            uint32_t jitter = 150 + arc4random_uniform(700);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(jitter * NSEC_PER_MSEC)),
                           dispatch_get_main_queue(), ^{ IKPGuardRunCheck(guardName); });
        }];
}

#endif

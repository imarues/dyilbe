// LCSign AutoSource: wait for the actual main tab interface, then request
// the existing addsource URL scheme once per launch/installation.
// Uses public UIKit APIs only; no method hooks or early startup UI calls.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static NSString *const kSourceURL = @"loadcontroller://addsource?url=https%3A%2F%2Fikiraplus.pages.dev%2FIPA-AR.json";
static NSString *const kCompletionKey = @"iKiraLCSignAutoSourceURLOpenedV1";
static BOOL gScheduled = NO;
static BOOL gAttemptedThisLaunch = NO;
static NSUInteger gChecks = 0;

// Skip off-screen and hidden views; a visible UITabBar is our signal that
// onboarding ended and the actual LCSign application shell is on screen.
static BOOL LCContainsVisibleTabBar(UIView *view, NSUInteger depth) {
    if (view == nil || depth > 40 || view.hidden || view.alpha < 0.01) return NO;
    if ([view isKindOfClass:[UITabBar class]]) return YES;
    for (UIView *child in view.subviews) {
        if (LCContainsVisibleTabBar(child, depth + 1)) return YES;
    }
    return NO;
}

static BOOL LCMainInterfaceReady(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if (app.applicationState != UIApplicationStateActive) return NO;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.hidden || window.alpha < 0.01 || !window.rootViewController) continue;
            // A UIKit-presented sheet may be a first-run agreement or an alert.
            if (window.rootViewController.presentedViewController != nil) continue;
            if (LCContainsVisibleTabBar(window, 0)) return YES;
        }
    }
    return NO;
}

static void LCScheduleCheck(void);

static void LCCheckAndAddSource(void) {
    NSCAssert([NSThread isMainThread], @"Must run on the main thread");
    if (gAttemptedThisLaunch || [[NSUserDefaults standardUserDefaults] boolForKey:kCompletionKey]) return;
    if (!LCMainInterfaceReady()) {
        if (++gChecks < 300) LCScheduleCheck();
        return;
    }

    // Let the first UI frame and SourceStore's loading settle.
    gAttemptedThisLaunch = YES; // one deep-link dispatch per process, no loops
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!LCMainInterfaceReady()) {
            gAttemptedThisLaunch = NO;
            LCScheduleCheck();
            return;
        }
        NSURL *url = [NSURL URLWithString:kSourceURL];
        if (!url) return;
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL opened) {
            // 'opened' means URL routing succeeded, not that a remote source
            // downloaded. SourceStore validates and persists the subscription.
            if (opened) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kCompletionKey];
            }
        }];
    });
}

static void LCScheduleCheck(void) {
    if (gScheduled || gAttemptedThisLaunch) return;
    gScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gScheduled = NO;
        LCCheckAndAddSource();
    });
}

__attribute__((constructor)) static void LCSourceInitialize(void) {
    // Deliberately do not touch UIApplication or any UI in the constructor.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *executable = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"];
        if (![executable isEqualToString:@"LoadController"]) return;
        NSNotificationCenter *notifications = [NSNotificationCenter defaultCenter];
        [notifications addObserverForName:UIApplicationDidBecomeActiveNotification
                                  object:nil queue:[NSOperationQueue mainQueue]
                              usingBlock:^(__unused NSNotification *note) {
            gChecks = 0;
            LCScheduleCheck();
        }];
        [notifications addObserverForName:UIWindowDidBecomeVisibleNotification
                                  object:nil queue:[NSOperationQueue mainQueue]
                              usingBlock:^(__unused NSNotification *note) {
            LCScheduleCheck();
        }];
        LCScheduleCheck();
    });
}

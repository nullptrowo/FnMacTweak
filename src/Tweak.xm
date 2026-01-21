#import "./globals.h"
#import "./views/popupViewController.h"
#import "../lib/fishhook.h"
#import <sys/sysctl.h>
#import <GameController/GameController.h>
#import <UIKit/UIKit.h>

// Variable global para guardar la ruta elegida por ti
NSString *customDataPath = nil;

// ============================================================================
// 1. DEVICE SPOOFING (Engañar al juego sobre el modelo de dispositivo)
// ============================================================================

static int (*orig_sysctl)(int*, u_int, void*, size_t*, void*, size_t) = NULL;
static int (*orig_sysctlbyname)(const char*, void*, size_t*, void*, size_t) = NULL;

static int pt_sysctl(int* name, u_int namelen, void* buf, size_t* size, void* arg0, size_t arg1) {
    if (name[0] == CTL_HW && (name[1] == HW_MACHINE || name[1] == HW_PRODUCT)) {
        if (buf == NULL) { *size = strlen(DEVICE_MODEL) + 1; } 
        else { strcpy((char*)buf, DEVICE_MODEL); }
        return 0;
    } else if (name[0] == CTL_HW && name[1] == HW_TARGET) {
        if (buf == NULL) { *size = strlen(OEM_ID) + 1; } 
        else { strcpy((char*)buf, OEM_ID); }
        return 0;
    }
    return orig_sysctl(name, namelen, buf, size, arg0, arg1);
}

static int pt_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
    if ((strcmp(name, "hw.machine") == 0) || (strcmp(name, "hw.product") == 0) || (strcmp(name, "hw.model") == 0)) {
        if (oldp == NULL) {
            int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
            if (oldlenp && *oldlenp < strlen(DEVICE_MODEL) + 1) *oldlenp = strlen(DEVICE_MODEL) + 1;
            return ret;
        } else {
            int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
            strncpy((char*)oldp, DEVICE_MODEL, strlen(DEVICE_MODEL) + 1);
            return ret;
        }
    }
    return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// ============================================================================
// 2. FILE SYSTEM REDIRECTION (La Magia)
// ============================================================================

// Puntero a la función original de iOS
static NSArray<NSString *> *(*orig_NSSearchPathForDirectoriesInDomains)(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);

// Nuestra función falsa que se ejecuta cuando el juego pide carpetas
NSArray<NSString *> *custom_NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde) {
    // Si el juego pide la carpeta "Documents" y tú configuraste una carpeta personalizada...
    if (directory == NSDocumentDirectory && customDataPath != nil) {
        // Le damos TU carpeta en lugar de la original
        return @[customDataPath];
    }
    // Si pide cualquier otra cosa, dejamos que iOS responda normal
    return orig_NSSearchPathForDirectoriesInDomains(directory, domainMask, expandTilde);
}

// ============================================================================
// 3. CONSTRUCTOR (Se ejecuta al iniciar el juego)
// ============================================================================

%ctor {
    // Cargar la carpeta guardada
    NSData* bookmark = [[NSUserDefaults standardUserDefaults] dataForKey:@"fnmactweak.datafolder"];
    if (bookmark) {
        BOOL stale = NO;
        NSError* error = nil;
        NSURL* url = [NSURL URLByResolvingBookmarkData:bookmark
                                               options:NSURLBookmarkResolutionWithoutUI
                                         relativeToURL:nil
                                   bookmarkDataIsStale:&stale
                                                 error:&error];
        if (url) {
            [url startAccessingSecurityScopedResource]; // Pedir permiso a iOS
            customDataPath = [url path]; // Guardar la ruta en nuestra variable
            NSLog(@"[FnMacTweak] REDIRECCION ACTIVADA A: %@", customDataPath);
        }
    }

    // Aplicar los ganchos (Hooks)
    struct rebinding rebindings[] = {
        {"sysctl", (void*)pt_sysctl, (void**)&orig_sysctl},
        {"sysctlbyname", (void*)pt_sysctlbyname, (void**)&orig_sysctlbyname},
        // Aquí enganchamos la función de búsqueda de directorios
        {"NSSearchPathForDirectoriesInDomains", (void*)custom_NSSearchPathForDirectoriesInDomains, (void**)&orig_NSSearchPathForDirectoriesInDomains}
    };
    rebind_symbols(rebindings, 3);
}

// ============================================================================
// 4. MENU & GESTURES
// ============================================================================

static void createPopup() {
    UIWindowScene* scene = (UIWindowScene*)[[UIApplication sharedApplication] connectedScenes].anyObject;
    popupWindow = [[UIWindow alloc] initWithWindowScene:scene];
    popupWindow.frame = CGRectMake(100, 100, 330, 400);
    popupWindow.windowLevel = UIWindowLevelAlert + 1;
    popupWindow.layer.cornerRadius = 15;
    popupWindow.clipsToBounds = true;
    popupViewController* popupVC = [popupViewController new];
    popupWindow.rootViewController = popupVC;
}

static void updateMouseLock(BOOL value) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow* keyWindow = [UIApplication sharedApplication].keyWindow;
    #pragma clang diagnostic pop
    UIViewController* mainViewController = keyWindow.rootViewController;
    [mainViewController setNeedsUpdateOfPrefersPointerLocked];
    if (value == false) { isAlreadyFocused = false; }
}

// Hook para detectar 3 DEDOS
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    UITapGestureRecognizer *threeFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuGesture:)];
    threeFingerTap.numberOfTouchesRequired = 3;
    [self addGestureRecognizer:threeFingerTap];
}
%new
- (void)handleMenuGesture:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (!popupWindow) createPopup();
        isPopupVisible = !isPopupVisible;
        popupWindow.hidden = !isPopupVisible;
        if (isPopupVisible) {
            isMouseLocked = false;
            updateMouseLock(isMouseLocked);
        }
    }
}
%end

// Hooks básicos de Fortnite
%hook IOSViewController
- (BOOL)prefersPointerLocked { return isMouseLocked; }
%end
%hook UIScreen
- (NSInteger)maximumFramesPerSecond { return 120; }
%end
%hook UITouch
- (UITouchType)type {
    UITouchType _original = %orig;
    if (!isMouseLocked && _original == UITouchTypeIndirectPointer) { return UITouchTypeDirect; } 
    else { return _original; }
}
%end

#import "./globals.h"
#import "./views/popupViewController.h"

#import "../lib/fishhook.h"
#import <sys/sysctl.h>

#import <GameController/GameController.h>
#import <UIKit/UIKit.h>

// --------- DEVICE SPOOFING (No tocar) ---------

static int (*orig_sysctl)(int*, u_int, void*, size_t*, void*, size_t) = NULL;
static int (*orig_sysctlbyname)(const char*, void*, size_t*, void*, size_t) = NULL;

static int pt_sysctl(int* name, u_int namelen, void* buf, size_t* size, void* arg0, size_t arg1) {
	if (name[0] == CTL_HW && (name[1] == HW_MACHINE || name[1] == HW_PRODUCT)) {
		if (buf == NULL) {
			*size = strlen(DEVICE_MODEL) + 1;
		} else {
			if (*size > strlen(DEVICE_MODEL)) {
				strcpy((char*)buf, DEVICE_MODEL);
			} else {
				return ENOMEM;
			}
		}
		return 0;
	} else if (name[0] == CTL_HW && name[1] == HW_TARGET) {
		if (buf == NULL) {
			*size = strlen(OEM_ID) + 1;
		} else {
			if (*size > strlen(OEM_ID)) {
				strcpy((char*)buf, OEM_ID);
			} else {
				return ENOMEM;
			}
		}
		return 0;
	}
	return orig_sysctl(name, namelen, buf, size, arg0, arg1);
}

static int pt_sysctlbyname(const char* name, void* oldp, size_t* oldlenp, void* newp, size_t newlen) {
	if ((strcmp(name, "hw.machine") == 0) || (strcmp(name, "hw.product") == 0) || (strcmp(name, "hw.model") == 0)) {
		if (oldp == NULL) {
			int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
			if (oldlenp && *oldlenp < strlen(DEVICE_MODEL) + 1) {
				*oldlenp = strlen(DEVICE_MODEL) + 1;
			}
			return ret;
		} else if (oldp != NULL) {
			int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
			const char* machine = DEVICE_MODEL;
			strncpy((char*)oldp, machine, strlen(machine));
			((char*)oldp)[strlen(machine)] = '\0';
			if (oldlenp)
				*oldlenp = strlen(machine) + 1;
			return ret;
		}
	} else if (strcmp(name, "hw.target") == 0) {
		if (oldp == NULL) {
			int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
			if (oldlenp && *oldlenp < strlen(OEM_ID) + 1) {
				*oldlenp = strlen(OEM_ID) + 1;
			}
			return ret;
		} else if (oldp != NULL) {
			int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
			const char* machine = OEM_ID;
			strncpy((char*)oldp, machine, strlen(machine));
			((char*)oldp)[strlen(machine)] = '\0';
			if (oldlenp)
				*oldlenp = strlen(machine) + 1;
			return ret;
		}
	}
	return orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
}

// --------- CONSTRUCTOR ---------

%ctor {
	struct rebinding rebindings[] = {{"sysctl", (void*)pt_sysctl, (void**)&orig_sysctl},
									 {"sysctlbyname", (void*)pt_sysctlbyname, (void**)&orig_sysctlbyname}};
	rebind_symbols(rebindings, 2);

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
			[url startAccessingSecurityScopedResource];
		}
	}
}

// --------- HELPER FUNCTIONS ---------

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

	if (value == false) {
		isAlreadyFocused = false;
	}
}

// --------- NUEVO HOOK TÁCTIL (3 DEDOS) ---------

%hook UIWindow

- (void)makeKeyAndVisible {
	%orig;
	// Inyectamos el gesto de 3 dedos
	UITapGestureRecognizer *threeFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMenuGesture:)];
	threeFingerTap.numberOfTouchesRequired = 3;
	[self addGestureRecognizer:threeFingerTap];
}

%new
- (void)handleMenuGesture:(UITapGestureRecognizer *)sender {
	if (sender.state == UIGestureRecognizerStateEnded) {
		// Crear popup si no existe
		if (!popupWindow) {
			createPopup();
		}

		// Alternar visibilidad
		isPopupVisible = !isPopupVisible;
		popupWindow.hidden = !isPopupVisible;

		// Si mostramos el menu, desbloqueamos el mouse
		if (isPopupVisible) {
			isMouseLocked = false;
			updateMouseLock(isMouseLocked);
		}
	}
}

%end

// --------- HOOKS ORIGINALES DE MOUSE/FPS ---------

%hook IOSViewController
- (BOOL)prefersPointerLocked {
	return isMouseLocked;
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
	return 120;
}
%end

%hook UITouch
- (UITouchType)type {
	UITouchType _original = %orig;
	if (!isMouseLocked && _original == UITouchTypeIndirectPointer) {
		return UITouchTypeDirect;
	} else {
		return _original;
	}
}
%end

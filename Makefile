GO_EASY_ON_ME = 1
FINALPACKAGE = 1
IGNORE_WARNINGS = 1
DEBUG = 0

ARCHS = arm64e
TARGET := iphone:clang:latest:26.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FnMacTweak

FnMacTweak_FILES = ./src/Tweak.xm ./src/views/popupViewController.m ./src/globals.m ./lib/fishhook.c
FnMacTweak_FRAMEWORKS = UIKit
FnMacTweak_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

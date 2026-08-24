TARGET := iphone:clang:latest:14.0
ARCHS = arm64
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = SeedCatcher
SeedCatcher_FILES = Tweak.cpp
SeedCatcher_CFLAGS = -fobjc-arc
SeedCatcher_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/library.mk

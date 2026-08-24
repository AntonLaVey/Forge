TARGET := iphone:clang:latest:14.0
ARCHS = arm64
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SeedCatcher
SeedCatcher_FILES = Tweak.mm
SeedCatcher_CFLAGS = -fobjc-arc
SeedCatcher_FRAMEWORKS = UIKit Foundation
SeedCatcher_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

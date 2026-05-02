ARCHS := arm64 arm64e
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := Helium

TARGET_CC := $(shell xcrun --sdk iphoneos --find clang)
TARGET_CXX := $(shell xcrun --sdk iphoneos --find clang++)
TARGET_LD := $(shell xcrun --sdk iphoneos --find clang++)

include $(THEOS)/makefiles/common.mk
APPLICATION_NAME = Helium

SRC_DIR := src
# Directories
APP_DIR := $(SRC_DIR)/app
BRIDGING_DIR := $(SRC_DIR)/bridging
CONTROLLERS_DIR := $(SRC_DIR)/controllers
EXTENSIONS_DIR := $(SRC_DIR)/extensions

HELPERS_DIR := $(SRC_DIR)/helpers
PRIV_DIR := $(HELPERS_DIR)/private_headers
TS_DIR := $(HELPERS_DIR)/ts

HUD_DIR := $(SRC_DIR)/hud

VIEWS_DIR := $(SRC_DIR)/views
NAVVIEWS_DIR := $(VIEWS_DIR)/navigation
WIDGETVIEWS_DIR := $(VIEWS_DIR)/widget
WIDGETSETVIEWS_DIR := $(VIEWS_DIR)/widgetset

WIDGETS_DIR := $(SRC_DIR)/widgets
WIDGET_EXT_DIR := $(SRC_DIR)/widget

$(APPLICATION_NAME)_USE_MODULES := 0
# Add Files From Directories
$(APPLICATION_NAME)_FILES += $(wildcard $(APP_DIR)/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard $(BRIDGING_DIR)/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard $(CONTROLLERS_DIR)/*.swift)
$(APPLICATION_NAME)_FILES += $(wildcard $(EXTENSIONS_DIR)/*.swift)
$(APPLICATION_NAME)_FILES += $(wildcard $(EXTENSIONS_DIR)/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard $(PRIV_DIR)/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard $(TS_DIR)/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard $(HUD_DIR)/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard $(VIEWS_DIR)/*.swift)
$(APPLICATION_NAME)_FILES += $(wildcard $(NAVVIEWS_DIR)/*.swift)
$(APPLICATION_NAME)_FILES += $(wildcard $(WIDGETVIEWS_DIR)/*.swift)
$(APPLICATION_NAME)_FILES += $(wildcard $(WIDGETSETVIEWS_DIR)/*.swift)
$(APPLICATION_NAME)_FILES += $(wildcard $(WIDGETS_DIR)/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard $(WIDGETS_DIR)/*.m)

$(APPLICATION_NAME)_CFLAGS += -fobjc-arc -Iinclude
$(APPLICATION_NAME)_CFLAGS += -include hud-prefix.pch -Wno-deprecated-declarations
$(APPLICATION_NAME)_SWIFTFLAGS += -import-objc-header src/bridging/Helium-Bridging-Header.h

$(APPLICATION_NAME)_FRAMEWORKS += CoreGraphics QuartzCore UIKit Foundation CoreLocation AVFoundation WidgetKit
$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices IOKit SpringBoardServices Weather WeatherFoundation WeatherUI MediaRemote
$(APPLICATION_NAME)_APPEXES = HeliumWidget

ifeq ($(TARGET_CODESIGN),ldid)
$(APPLICATION_NAME)_CODESIGN_FLAGS += -Sent.plist
else
$(APPLICATION_NAME)_CODESIGN_FLAGS += --entitlements ent.plist $(TARGET_CODESIGN_FLAGS)
endif

# Widget Extension
APPEXTENSION_NAME = HeliumWidget

HeliumWidget_FILES = $(WIDGET_EXT_DIR)/HeliumWidget.swift $(WIDGET_EXT_DIR)/WidgetSpawnHelper.m
HeliumWidget_FRAMEWORKS = WidgetKit SwiftUI
HeliumWidget_CFLAGS = -fobjc-arc
HeliumWidget_SWIFTFLAGS = -import-objc-header $(WIDGET_EXT_DIR)/HeliumWidget-Bridging-Header.h
HeliumWidget_RESOURCE_DIRS = $(WIDGET_EXT_DIR)/Resources
HeliumWidget_INSTALL_PATH = /Applications/Helium.app/PlugIns
HeliumWidget_USE_MODULES := 0

ifeq ($(TARGET_CODESIGN),ldid)
HeliumWidget_CODESIGN_FLAGS = -Swidget-ent.plist
else
HeliumWidget_CODESIGN_FLAGS = --entitlements widget-ent.plist $(TARGET_CODESIGN_FLAGS)
endif

include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/appextension.mk

after-stage::
	$(ECHO_NOTHING)mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)/Applications/Helium.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr Helium.tipa Payload; cd -;$(ECHO_END)

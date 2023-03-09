ifeq ($(OS),Windows_NT)
	SHELL := powershell.exe
	.SHELLFLAGS := 
	SCRIPT_DIR := scripts/ps
	SCRIPT_EXT := ps1
	PLATFORM := Windows_x86_64
	BUILD_DEP := $(shell $(SCRIPT_DIR)/get_file_list.ps1 package) $(shell $(SCRIPT_DIR)/get_file_list.ps1 resources) $(shell $(SCRIPT_DIR)/get_file_list.ps1 shims)
else
	SHELL := bash
	SCRIPT_DIR := scripts/posix
	SCRIPT_EXT := sh
	PLATFORM := $(shell uname)_$(shell uname -m)
	BUILD_DEP := $(shell find package -type f) $(shell find resources -type f) $(shell find shims -type f) 
endif

VERSION_TAG := $(shell git describe --abbrev=0)
VERSION_BUILD := $(shell git rev-list $(VERSION_TAG)..HEAD --count)

ifeq ($(PLATFORM), Linux_x86_64)
	PLATFORM_DIR := linux_x86_64
else ifeq ($(PLATFORM), Darwin_x86_64)
	PLATFORM_DIR := darwin_x86_64
else ifeq ($(PLATFORM), Darwin_arm64)
	PLATFORM_DIR := darwin_arm64
else ifeq ($(PLATFORM), Windows_x86_64)
	PLATFORM_DIR := windows_x86_64
endif

BUILD_TARGET := Splunk_SA_Scientific_Python_$(PLATFORM_DIR)
FREEZE_TARGET := $(PLATFORM_DIR)/environment.yml
BLACKLIST := $(PLATFORM_DIR)/blacklist.txt

ifneq (,$(filter freeze,$(MAKECMDGOALS)))
	ifeq ($(OS),Windows_NT)
		export ENVIRONMENT_FILE = environment.win64.yml
	else
		ifeq ($(PLATFORM), Darwin_arm64)
			export ENVIRONMENT_FILE = environment.darwin_arm64.yml
		else
			export ENVIRONMENT_FILE = environment.nix.yml
		endif
	endif
else
	export ENVIRONMENT_FILE = 
endif

export VERSION ?= $(VERSION_TAG)
export BUILD ?= $(VERSION_BUILD)

.PHONY: analyze build clean dist fossa freeze license publish linkapp
COMMON_DEPS := $(SCRIPT_DIR)/prereq.$(SCRIPT_EXT) Makefile

build/miniconda:
	$(SCRIPT_DIR)/install_miniconda.$(SCRIPT_EXT)

build/venv: build/miniconda $(ENVIRONMENT_FILE) $(BLACKLIST) $(SCRIPT_DIR)/venv.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_DIR)/venv.$(SCRIPT_EXT)

$(FREEZE_TARGET): build/venv $(SCRIPT_DIR)/freeze.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_DIR)/freeze.$(SCRIPT_EXT)

freeze: $(FREEZE_TARGET)

build/miniconda-repack.tar.gz: build/venv $(SCRIPT_DIR)/conda_pack.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_DIR)/conda_pack.$(SCRIPT_EXT)

build/$(BUILD_TARGET): build/miniconda-repack.tar.gz $(SCRIPT_DIR)/build.$(SCRIPT_EXT) $(BUILD_DEP) $(COMMON_DEPS)
	$(SCRIPT_DIR)/build.$(SCRIPT_EXT)

build: build/$(BUILD_TARGET)

build/$(BUILD_TARGET).tgz: build/$(BUILD_TARGET)
	$(SCRIPT_DIR)/dist.$(SCRIPT_EXT)

dist: build/$(BUILD_TARGET).tgz

analyze: build/venv $(SCRIPT_DIR)/analyze.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_DIR)/analyze.$(SCRIPT_EXT)

fossa: build/venv $(SCRIPT_DIR)/fossa.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_DIR)/fossa.$(SCRIPT_EXT)

license: build/venv $(SCRIPT_DIR)/license.$(SCRIPT_EXT) tools/license.py $(COMMON_DEPS)
	$(SCRIPT_DIR)/license.$(SCRIPT_EXT)

publish:
	$(SCRIPT_DIR)/publish.sh

clean:
	$(SCRIPT_DIR)/clean.$(SCRIPT_EXT)

linkapp:
	ln -s $$PWD/build/Splunk_SA_Scientific_Python_$(PLATFORM_DIR) $$SPLUNK_HOME/etc/apps/Splunk_SA_Scientific_Python_$(PLATFORM_DIR)

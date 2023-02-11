VERSION := $(shell git describe --tags)
VERSION_TAG := $(shell git describe --abbrev=0)
VERSION_BUILD := $(shell git rev-list $(VERSION_TAG)..HEAD --count)

ifeq ($(OS),Windows_NT)
	PLATFORM := Windows_x86_64
	SCRIPT_DIR := scripts/ps
	SCRIPT_SHELL := powershell
	SCRIPT_EXT := ps1
	BUILD_DEP := $(shell powershell Get-Children -Path package -File) $(shell powershell Get-Children -Path resources -File) $(shell powershell Get-Children -Path shims -File)

else
	PLATFORM := $(shell uname)_$(shell uname -m)
	SCRIPT_DIR := scripts/posix
	SCRIPT_SHELL := bash
	SCRIPT_EXT := sh
	BUILD_DEP := $(shell find package -type f) $(shell find resources -type f) $(shell find shims -type f) 
endif

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
		export ENVIRONMENT_FILE = environment.nix.yml
	endif
else
	export ENVIRONMENT_FILE = 
endif

export VERSION=$(VERSION_TAG)
export BUILD=$(VERSION_BUILD)

.PHONY: analyze build clean fossa freeze license publish
COMMON_DEPS := $(SCRIPT_DIR)/prereq.$(SCRIPT_EXT) Makefile

build/miniconda:
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/install_miniconda.$(SCRIPT_EXT)

build/venv: build/miniconda $(ENVIRONMENT_FILE) $(BLACKLIST) $(SCRIPT_DIR)/venv.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/venv.$(SCRIPT_EXT)

$(FREEZE_TARGET): build/venv $(SCRIPT_DIR)/freeze.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/freeze.$(SCRIPT_EXT)

freeze: $(FREEZE_TARGET)

build/miniconda-repack.tar.gz: build/venv $(SCRIPT_DIR)/conda_pack.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/conda_pack.$(SCRIPT_EXT)

build/$(BUILD_TARGET): build/miniconda-repack.tar.gz $(SCRIPT_DIR)/build.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/build.$(SCRIPT_EXT)

build: build/$(BUILD_TARGET)

dist: build/$(BUILD_TARGET)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/dist.$(SCRIPT_EXT)

analyze: build/venv $(SCRIPT_DIR)/analyze.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/analyze.$(SCRIPT_EXT)

fossa: build/venv $(SCRIPT_DIR)/fossa.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/fossa.$(SCRIPT_EXT)

license: build/venv $(SCRIPT_DIR)/license.$(SCRIPT_EXT) tools/license.py $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/license.$(SCRIPT_EXT)

publish: dist $(SCRIPT_DIR)/publish.$(SCRIPT_EXT) $(COMMON_DEPS)
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/publish.$(SCRIPT_EXT)

clean:
	$(SCRIPT_SHELL) $(SCRIPT_DIR)/clean.$(SCRIPT_EXT)

VERSION := $(shell git describe --tags)
VERSION_TAG := $(shell git describe --abbrev=0)
VERSION_BUILD := $(shell git rev-list $(VERSION_TAG)..HEAD --count)

PLATFORM := $(shell uname)_$(shell uname -m)
POSIX_SCRIPT_DIR := scripts/posix

ifeq ($(PLATFORM), Linux_x86_64)
	PLATFORM_DIR := linux_x86_64
	SCRIPT_DIR := $(POSIX_SCRIPT_DIR)
else ifeq ($(PLATFORM), Darwin_x86_64)
	PLATFORM_DIR := darwin_x86_64
	SCRIPT_DIR := $(POSIX_SCRIPT_DIR)
else
	$(error $(PLATFORM) not supported)
endif

BUILD_TARGET := Splunk_SA_Scientific_Python_$(PLATFORM_DIR)
FREEZE_TARGET := $(PLATFORM_DIR)/environment.yml
BLACKLIST := $(PLATFORM_DIR)/blacklist.txt

ifneq (,$(filter freeze,$(MAKECMDGOALS)))
	ENVIRONMENT_FILE := environment.nix.yml
else
	ENVIRONMENT_FILE := 
endif

.PHONY: analyze build clean fossa freeze license publish
COMMON_DEPS := $(SCRIPT_DIR)/prereq.sh Makefile

build/miniconda: $(SCRIPT_DIR)/miniconda_settings.sh $(SCRIPT_DIR)/install_miniconda.sh $(COMMON_DEPS)
	bash $(SCRIPT_DIR)/install_miniconda.sh

build/venv: build/miniconda $(ENVIRONMENT_FILE) $(BLACKLIST) $(SCRIPT_DIR)/venv.sh $(COMMON_DEPS)
	ENVIRONMENT_FILE=$(ENVIRONMENT_FILE) bash $(SCRIPT_DIR)/venv.sh

$(FREEZE_TARGET): build/venv $(SCRIPT_DIR)/freeze.sh $(COMMON_DEPS)
	bash $(SCRIPT_DIR)/freeze.sh

freeze: $(FREEZE_TARGET)

build/miniconda-repack.tar.gz: build/venv $(SCRIPT_DIR)/conda_pack.sh $(COMMON_DEPS)
	bash $(SCRIPT_DIR)/conda_pack.sh

build/$(BUILD_TARGET): build/miniconda-repack.tar.gz $(SCRIPT_DIR)/build.sh $(shell find package -type f) $(shell find resources -type -f) $(COMMON_DEPS)
	VERSION=$(VERSION_TAG) BUILD=$(VERSION_BUILD) bash $(SCRIPT_DIR)/build.sh

build: build/$(BUILD_TARGET)

dist: build/$(BUILD_TARGET)
	bash $(SCRIPT_DIR)/dist.sh

analyze: build/venv $(SCRIPT_DIR)/analyze.sh $(COMMON_DEPS)
	bash $(SCRIPT_DIR)/analyze.sh

fossa: build/venv $(SCRIPT_DIR)/fossa.sh $(COMMON_DEPS)
	bash $(SCRIPT_DIR)/fossa.sh

license: build/venv $(SCRIPT_DIR)/license.sh tools/license.py $(COMMON_DEPS)
	bash $(SCRIPT_DIR)/license.sh

publish: dist $(SCRIPT_DIR)/publish.sh $(COMMON_DEPS)
	VERSION=$(VERSION_TAG) bash $(SCRIPT_DIR)/publish.sh

clean:
	bash $(SCRIPT_DIR)/clean.sh

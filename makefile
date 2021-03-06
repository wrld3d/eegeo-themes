rwildcard=$(wildcard $1$2) $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2))

SRC_DIR := themes
BUILD_DIR := build
LANDMARK_TEXTURES_VERSION_FILE := $(BUILD_DIR)/landmark_textures_version/version.txt
INTERIOR_MATERIALS_VERSION_FILE := $(BUILD_DIR)/interior_materials_version/version.txt
COMPRESSED_DIR := $(BUILD_DIR)/compressed_textures
GZIP_DIR := $(BUILD_DIR)/gzipped_assets
GZIPPED_ASSETS_DIR := $(GZIP_DIR)/Assets
BUCKET_NAME := s3://myworld_developer_destination_resources
BUCKET_PATH := mobile-themes-new
REMOTE_SYNC_DIR := $(BUCKET_NAME)/$(BUCKET_PATH)/sync
VERSION_NAME := v$(VERSION)
REMOTE_STORE_PATH := $(BUCKET_PATH)/$(VERSION_NAME)
REMOTE_BUILD_DIR := $(BUCKET_NAME)/$(REMOTE_STORE_PATH)

SRC_POD_FILES := $(call rwildcard,$(SRC_DIR)/,*.POD)
DST_POD_FILES := $(patsubst $(SRC_DIR)/%,$(GZIPPED_ASSETS_DIR)/%.gz,$(SRC_POD_FILES))

SRC_PNG_FILES := $(call rwildcard,$(SRC_DIR)/,*.png)

SRC_CUBE_POSX_FILES := $(filter %_posX.png,$(SRC_PNG_FILES))
SRC_CUBE_NEGX_FILES := $(SRC_CUBE_POSX_FILES:_posX.png=_negX.png) 
SRC_CUBE_POSY_FILES := $(SRC_CUBE_POSX_FILES:_posX.png=_posY.png)
SRC_CUBE_NEGY_FILES := $(SRC_CUBE_POSX_FILES:_posX.png=_negY.png)
SRC_CUBE_POSZ_FILES := $(SRC_CUBE_POSX_FILES:_posX.png=_posZ.png)
SRC_CUBE_NEGZ_FILES := $(SRC_CUBE_POSX_FILES:_posX.png=_negZ.png)
SRC_CUBE_FILES := $(SRC_CUBE_NEGX_FILES) $(SRC_CUBE_POSX_FILES) $(SRC_CUBE_NEGY_FILES) $(SRC_CUBE_POSY_FILES) $(SRC_CUBE_NEGZ_FILES) $(SRC_CUBE_POSZ_FILES)
SRC_NON_CUBE_FILES := $(filter-out $(SRC_CUBE_FILES), $(SRC_PNG_FILES))

PVR_FILES := $(patsubst $(SRC_DIR)/%.png,$(COMPRESSED_DIR)/%.pvr,$(SRC_NON_CUBE_FILES))
KTX_FILES := $(patsubst $(SRC_DIR)/%.png,$(COMPRESSED_DIR)/%.ktx,$(SRC_NON_CUBE_FILES))
DDS_FILES := $(patsubst $(SRC_DIR)/%.png,$(COMPRESSED_DIR)/%.dds,$(SRC_NON_CUBE_FILES))
DST_PNG_FILES := $(patsubst $(SRC_DIR)/%,$(COMPRESSED_DIR)/%,$(SRC_PNG_FILES))
DST_WEB_PNG_FILES := $(patsubst $(SRC_DIR)/%.png,$(COMPRESSED_DIR)/%.webgl.png,$(SRC_PNG_FILES))

PVR_CUBE_FILES := $(patsubst $(SRC_DIR)/%_posX.png,$(COMPRESSED_DIR)/%_cubemap.pvr,$(SRC_CUBE_POSX_FILES))
KTX_CUBE_FILES := $(patsubst $(SRC_DIR)/%_posX.png,$(COMPRESSED_DIR)/%_cubemap.ktx,$(SRC_CUBE_POSX_FILES))
DDS_CUBE_FILES := $(patsubst $(SRC_DIR)/%_posX.png,$(COMPRESSED_DIR)/%_cubemap.dds,$(SRC_CUBE_POSX_FILES))

ALL_COMPRESSED_FILES := $(PVR_FILES) $(PVR_CUBE_FILES) $(KTX_FILES) $(KTX_CUBE_FILES) $(DDS_FILES) $(DDS_CUBE_FILES) $(DST_PNG_FILES) $(DST_WEB_PNG_FILES) 
ALL_GZIP_FILES := $(patsubst $(COMPRESSED_DIR)/%,$(GZIPPED_ASSETS_DIR)/%.gz,$(ALL_COMPRESSED_FILES))

TEX_TOOL = ./lib/PVRTexToolCL.exe
WEB_OPTIMIZE_PNG = python optimize_png_for_web.py 
PVR_COMPRESS = $(TEX_TOOL) -f PVRTC1_4 -m -flip y -legacypvr
PVR_COMPRESS_CUBE = $(TEX_TOOL) -f PVRTC1_4 -m -legacypvr
KTX_COMPRESS = $(TEX_TOOL) -f ETC1 -m -flip y
KTX_COMPRESS_CUBE = $(TEX_TOOL) -f ETC1 -m 
DDS_COMPRESS = $(TEX_TOOL) -f BC1 -m -flip y 
DDS_COMPRESS_CUBE = $(TEX_TOOL) -f BC1 -m 

MKDIR = mkdir -p
CP = cp 
GZIP = gzip
AWS = AWS_SECRET_KEY_ID=$(AWS_SECRET_KEY_ID) AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) aws
S3CP = $(AWS) s3 cp --recursive --content-encoding "gzip"
S3SYNC = $(AWS) s3 sync --content-encoding "gzip" --delete
PREP_MANIFEST = cpp 
BUILD_MANIFEST = ./venv_wrapper.sh python build_manifest.py 
CHECK_MANIFEST = ./venv_wrapper.sh python check_manifest.py
CHECK_THEME_PATHS = ./venv_wrapper.sh python check_theme_paths.py

MANIFEST_SRC_DIR := manifest
MANIFEST_ROOTS_DIR := $(MANIFEST_SRC_DIR)/manifest_roots
MANIFEST_ROOT_FILES := $(wildcard $(MANIFEST_ROOTS_DIR)/*.yaml)
MANIFEST_BUILD_DIR := $(BUILD_DIR)/manifest
SRC_MANIFEST_FILES := $(call rwildcard,$(MANIFEST_SRC_DIR)/,*.yaml)

VERSIONS_JSON := $(MANIFEST_BUILD_DIR)/versions.json
GZIPPED_VERSIONS_JSON := $(GZIP_DIR)/versions.json
EMIT_VERSION_JSON = ./venv_wrapper.sh python emit_version_json.py -s "$(REMOTE_STORE_PATH)" -o "$(VERSIONS_JSON)"

DST_MANIFEST_FILES := $(patsubst $(MANIFEST_ROOTS_DIR)/%.yaml,$(GZIP_DIR)/%/manifest.txt.gz,$(wildcard $(MANIFEST_ROOTS_DIR)/*.yaml))
WEB_DST_MANIFEST_FILES := $(patsubst $(MANIFEST_ROOTS_DIR)/%.yaml,$(GZIP_DIR)/%/web.manifest.txt.gz,$(wildcard $(MANIFEST_ROOTS_DIR)/*.yaml))
SSL_DST_MANIFEST_FILES := $(patsubst $(MANIFEST_ROOTS_DIR)/%.yaml,$(GZIP_DIR)/%/ssl.manifest.txt.gz,$(wildcard $(MANIFEST_ROOTS_DIR)/*.yaml))
PREPPED_YAML_FILES := $(patsubst $(MANIFEST_ROOTS_DIR)/%.yaml,$(MANIFEST_BUILD_DIR)/%.yaml.prep,$(wildcard $(MANIFEST_ROOTS_DIR)/*.yaml))

UNQUANTIZABLE_TEXTURES = $(BUILD_DIR)/unquantizable_textures.txt 
PREV_UNQUANTIZABLE_TEXTURES = $(BUILD_DIR)/unquantizable_textures.txt.prev

.SECONDARY:
.PHONY: all
all: check-env $(ALL_GZIP_FILES) $(DST_MANIFEST_FILES) $(WEB_DST_MANIFEST_FILES) $(SSL_DST_MANIFEST_FILES) $(DST_POD_FILES) $(VERSIONS_JSON) $(PREV_UNQUANTIZABLE_TEXTURES) 
	$(S3SYNC) $(GZIP_DIR)/ $(REMOTE_SYNC_DIR)/
	$(S3CP) $(REMOTE_SYNC_DIR)/ $(REMOTE_BUILD_DIR)/

$(MANIFEST_BUILD_DIR)/%.yaml.prep:$(MANIFEST_ROOTS_DIR)/%.yaml $(SRC_MANIFEST_FILES)
	$(MKDIR) $(dir $@) 
	$(PREP_MANIFEST) "$<" > "$@"

.PHONY: .FORCE

# Always rebuild this as it contains references to the version directory.
$(MANIFEST_BUILD_DIR)/%/manifest.txt:$(MANIFEST_BUILD_DIR)/%.yaml.prep .FORCE
	$(MKDIR) $(dir $@) 
	$(BUILD_MANIFEST) "$<" $(VERSION_NAME) $(EEGEO_ASSETS_HOST_NAME) $(THEME_ASSETS_HOST_NAME) $(LANDMARK_TEXTURES_VERSION_FILE) $(INTERIOR_MATERIALS_VERSION_FILE) > "$@"
	$(CHECK_MANIFEST) "$@"	

# Always rebuild this as it contains references to the version directory.
$(MANIFEST_BUILD_DIR)/%/web.manifest.txt:$(MANIFEST_BUILD_DIR)/%.yaml.prep .FORCE
	$(MKDIR) $(dir $@) 
	$(BUILD_MANIFEST) "$<" $(VERSION_NAME) $(WEB_EEGEO_ASSETS_HOST_NAME) $(WEB_THEME_ASSETS_HOST_NAME) $(LANDMARK_TEXTURES_VERSION_FILE) $(INTERIOR_MATERIALS_VERSION_FILE) > "$@"
	$(CHECK_MANIFEST) "$@"	

# Always rebuild this as it contains references to the version directory.
$(MANIFEST_BUILD_DIR)/%/ssl.manifest.txt:$(MANIFEST_BUILD_DIR)/%.yaml.prep .FORCE
	$(MKDIR) $(dir $@) 
	$(BUILD_MANIFEST) "$<" $(VERSION_NAME) $(SSL_EEGEO_ASSETS_HOST_NAME) $(SSL_THEME_ASSETS_HOST_NAME) $(LANDMARK_TEXTURES_VERSION_FILE) $(INTERIOR_MATERIALS_VERSION_FILE) > "$@"
	$(CHECK_MANIFEST) "$@"

# Always rebuild this as it includes the versioned URLs
$(VERSIONS_JSON):$(DST_MANIFEST_FILES) .FORCE
	$(EMIT_VERSION_JSON) $(MANIFEST_ROOT_FILES)
	cat $(VERSIONS_JSON) | gzip -n --stdout > $(GZIPPED_VERSIONS_JSON)

$(GZIP_DIR)/%.txt.gz:$(MANIFEST_BUILD_DIR)/%.txt
	$(MKDIR) $(dir $@)
	cat $< | gzip -n --stdout >$@

$(COMPRESSED_DIR)/%.pvr:$(SRC_DIR)/%.png
	$(MKDIR) $(dir $@) 
	$(PVR_COMPRESS) -i "$<" -o "$@"

$(COMPRESSED_DIR)/%_cubemap.pvr:$(SRC_DIR)/%_posX.png
	$(MKDIR) $(dir $@)
	$(PVR_COMPRESS_CUBE) -cube -i "$(<)","$(<:_posX.png=_negX.png)","$(<:_posX.png=_posY.png)","$(<:_posX.png=_negY.png)","$(<:_posX.png=_posZ.png)","$(<:_posX.png=_negZ.png)" -o "$@"

$(COMPRESSED_DIR)/%.ktx:$(SRC_DIR)/%.png
	$(MKDIR) $(dir $@)
	$(KTX_COMPRESS) -i "$<" -o "$@"

$(COMPRESSED_DIR)/%_cubemap.ktx:$(SRC_DIR)/%_posX.png
	$(MKDIR) $(dir $@)
	$(KTX_COMPRESS_CUBE) -cube -i "$(<)","$(<:_posX.png=_negX.png)","$(<:_posX.png=_posY.png)","$(<:_posX.png=_negY.png)","$(<:_posX.png=_posZ.png)","$(<:_posX.png=_negZ.png)" -o "$@"

$(COMPRESSED_DIR)/%.dds:$(SRC_DIR)/%.png
	$(MKDIR) $(dir $@)
	$(DDS_COMPRESS) -i "$<" -o "$@"

$(COMPRESSED_DIR)/%_cubemap.dds:$(SRC_DIR)/%_posX.png
	$(MKDIR) $(dir $@)
	$(DDS_COMPRESS_CUBE) -cube -i "$(<)","$(<:_posX.png=_negX.png)","$(<:_posX.png=_posY.png)","$(<:_posX.png=_negY.png)","$(<:_posX.png=_posZ.png)","$(<:_posX.png=_negZ.png)" -o "$@"

$(COMPRESSED_DIR)/%.png:$(SRC_DIR)/%.png
	$(MKDIR) $(dir $@)
	$(CP) "$<" "$@"

$(COMPRESSED_DIR)/%.webgl.png : $(SRC_DIR)/%.png $(UNQUANTIZABLE_TEXTURES)
	@$(MKDIR) $(dir $@)
	@$(WEB_OPTIMIZE_PNG) -i "$<" -o "$@" -u $(UNQUANTIZABLE_TEXTURES)
	
$(GZIPPED_ASSETS_DIR)/%.gz:$(COMPRESSED_DIR)/%
	$(MKDIR) $(dir $@)
	cat $< | gzip -n --stdout >$@

$(GZIPPED_ASSETS_DIR)/%.POD.gz:$(SRC_DIR)/%.POD
	$(MKDIR) $(dir $@)
	cat $< | gzip -n --stdout >$@

$(UNQUANTIZABLE_TEXTURES):$(PREPPED_YAML_FILES)
	$(MKDIR) $(dir $@)
	 python list_unquantizable_textures.py --manifest_directory=$(MANIFEST_BUILD_DIR) > $@

$(PREV_UNQUANTIZABLE_TEXTURES):$(DST_WEB_PNG_FILES) $(UNQUANTIZABLE_TEXTURES)
	rm -f $@ 
	cp $(UNQUANTIZABLE_TEXTURES) $@

.PHONY: check-env
check-env:
ifndef VERSION
		$(error VERSION not defined. Specify it like this "make VERSION=<YOUR VERSION>")
endif
ifndef AWS_ACCESS_KEY_ID
		$(error AWS_ACCESS_KEY_ID not defined. Specify it like this "make AWS_ACCESS_KEY_ID=<YOUR KEY>")
endif
ifndef AWS_SECRET_ACCESS_KEY
		$(error AWS_SECRET_ACCESS_KEY not defined. Specify it like this "make AWS_SECRET_ACCESS_KEY=<YOUR KEY>")
endif
ifndef EEGEO_ASSETS_HOST_NAME
		$(error EEGEO_ASSETS_HOST_NAME not defined. Specify it like this "make EEGEO_ASSETS_HOST_NAME=<EEGEO ASSETS HOST NAME>")
endif
ifndef THEME_ASSETS_HOST_NAME
		$(error THEME_ASSETS_HOST_NAME not defined. Specify it like this "make THEME_ASSETS_HOST_NAME=<YOUR THEME ASSETS HOST NAME>")
endif
ifndef WEB_EEGEO_ASSETS_HOST_NAME
		$(error WEB_EEGEO_ASSETS_HOST_NAME not defined. Specify it like this "make WEB_EEGEO_ASSETS_HOST_NAME=<EEGEO ASSETS HOST NAME>")
endif
ifndef WEB_THEME_ASSETS_HOST_NAME
		$(error WEB_THEME_ASSETS_HOST_NAME not defined. Specify it like this "make WEB_THEME_ASSETS_HOST_NAME=<YOUR ASSETS HOST NAME>")
endif
ifndef SSL_EEGEO_ASSETS_HOST_NAME
		$(error SSL_EEGEO_ASSETS_HOST_NAME not defined. Specify it like this "make SSL_EEGEO_ASSETS_HOST_NAME=<EEGEO ASSETS HOST NAME>")
endif
ifndef SSL_THEME_ASSETS_HOST_NAME
		$(error SSL_THEME_ASSETS_HOST_NAME not defined. Specify it like this "make SSL_THEME_ASSETS_HOST_NAME=<YOUR ASSETS HOST NAME>")
endif

.PHONY: clean
clean: 
	rm -rf $(BUILD_DIR)

.PHONY: check_theme_paths 
check_theme_paths:$(PREPPED_YAML_FILES)
	$(CHECK_THEME_PATHS) --source_files $(PREPPED_YAML_FILES) --texture_directory "themes/"


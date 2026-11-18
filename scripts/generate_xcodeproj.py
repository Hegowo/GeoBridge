#!/usr/bin/env python3
"""
Generates GeoBridge.xcodeproj from the source tree.
Run from the repository root:  python3 scripts/generate_xcodeproj.py
"""
import os
import uuid
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def make_id():
    """24-character uppercase hex string used as Xcode object key."""
    return uuid.uuid4().hex.upper()[:24]

# ── Collect source files ──────────────────────────────────────────────────────

def collect_swift_files(directory):
    sources = []
    for dirpath, _, filenames in os.walk(directory):
        for fn in sorted(filenames):
            if fn.endswith('.swift'):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, ROOT)
                sources.append(rel)
    return sorted(sources)

app_sources = collect_swift_files(os.path.join(ROOT, 'GeoBridge'))
test_sources = collect_swift_files(os.path.join(ROOT, 'GeoBridgeTests'))
fixture_dir = os.path.join(ROOT, 'GeoBridgeTests', 'Fixtures')
fixture_files = [
    os.path.relpath(os.path.join(fixture_dir, f), ROOT)
    for f in sorted(os.listdir(fixture_dir))
    if not f.startswith('.')
] if os.path.isdir(fixture_dir) else []

resource_files = []
for dirpath, _, filenames in os.walk(os.path.join(ROOT, 'GeoBridge', 'Resources')):
    for fn in sorted(filenames):
        if not fn.startswith('.'):
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT)
            resource_files.append(rel)

# ── Assign UUIDs ──────────────────────────────────────────────────────────────

PROJECT_ID = make_id()
MAIN_GROUP_ID = make_id()
PRODUCTS_GROUP_ID = make_id()
APP_TARGET_ID = make_id()
TEST_TARGET_ID = make_id()
APP_PRODUCT_REF_ID = make_id()
TEST_PRODUCT_REF_ID = make_id()
APP_SOURCES_PHASE_ID = make_id()
APP_FRAMEWORKS_PHASE_ID = make_id()
APP_RESOURCES_PHASE_ID = make_id()
TEST_SOURCES_PHASE_ID = make_id()
TEST_FRAMEWORKS_PHASE_ID = make_id()
TEST_RESOURCES_PHASE_ID = make_id()
DEBUG_CONFIG_LIST_APP = make_id()
RELEASE_CONFIG_LIST_APP = make_id()
DEBUG_CONFIG_LIST_TEST = make_id()
RELEASE_CONFIG_LIST_TEST = make_id()
DEBUG_CONFIG_LIST_PROJECT = make_id()
RELEASE_CONFIG_LIST_PROJECT = make_id()
CONFIG_LIST_APP_ID = make_id()
CONFIG_LIST_TEST_ID = make_id()
CONFIG_LIST_PROJECT_ID = make_id()
MAPKIT_REF_ID = make_id()
APP_TEST_DEPENDENCY_ID = make_id()
SWIFT_STDLIB_REF_ID = make_id()

# Per-file UUIDs
file_refs = {}     # path -> fileRef ID
build_files = {}   # path -> buildFile ID
test_file_refs = {}
test_build_files = {}
fixture_refs = {}
fixture_build_files = {}
resource_refs = {}
resource_build_files = {}

for p in app_sources:
    file_refs[p] = make_id()
    build_files[p] = make_id()

for p in test_sources:
    test_file_refs[p] = make_id()
    test_build_files[p] = make_id()

for p in fixture_files:
    fixture_refs[p] = make_id()
    fixture_build_files[p] = make_id()

for p in resource_files:
    resource_refs[p] = make_id()
    resource_build_files[p] = make_id()

# ── Build pbxproj sections ─────────────────────────────────────────────────────

def pbx_file_reference(path, file_id, source_tree='SOURCE_ROOT', file_type=None):
    ext = os.path.splitext(path)[1]
    if file_type is None:
        types = {'.swift': 'sourcecode.swift', '.json': 'text.json',
                 '.plist': 'text.plist.xml', '.entitlements': 'text.plist.entitlements',
                 '.xcassets': 'folder.assetcatalog', '.sh': 'text.script.sh'}
        file_type = types.get(ext, 'text')
    name = os.path.basename(path)
    return (
        f'\t\t{file_id} = {{\n'
        f'\t\t\tisa = PBXFileReference;\n'
        f'\t\t\tlastKnownFileType = {file_type};\n'
        f'\t\t\tpath = "{name}";\n'
        f'\t\t\tname = "{name}";\n'
        f'\t\t\tsourceTree = SOURCE_ROOT;\n'
        f'\t\t\tpath = "{path}";\n'
        f'\t\t}};\n'
    )

lines = []

lines.append('// !$*UTF8*$!')
lines.append('{')
lines.append('\tarchiveVersion = 1;')
lines.append('\tclasses = {')
lines.append('\t};')
lines.append('\tobjectVersion = 56;')
lines.append('\tobjects = {')
lines.append('')

# ── PBXBuildFile ────────────────────────────────────────────────
lines.append('\n/* Begin PBXBuildFile section */')
for p, bid in build_files.items():
    fid = file_refs[p]
    name = os.path.basename(p)
    lines.append(f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')

for p, bid in test_build_files.items():
    fid = test_file_refs[p]
    name = os.path.basename(p)
    lines.append(f'\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')

for p, bid in fixture_build_files.items():
    fid = fixture_refs[p]
    name = os.path.basename(p)
    lines.append(f'\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')

for p, bid in resource_build_files.items():
    fid = resource_refs[p]
    name = os.path.basename(p)
    lines.append(f'\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};')

lines.append('/* End PBXBuildFile section */')

# ── PBXFileReference ────────────────────────────────────────────
lines.append('\n/* Begin PBXFileReference section */')
lines.append(f'\t\t{APP_PRODUCT_REF_ID} /* GeoBridge.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = GeoBridge.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
lines.append(f'\t\t{TEST_PRODUCT_REF_ID} /* GeoBridgeTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = GeoBridgeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')

for p, fid in file_refs.items():
    name = os.path.basename(p)
    lines.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{p}"; sourceTree = SOURCE_ROOT; }};')

for p, fid in test_file_refs.items():
    name = os.path.basename(p)
    lines.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{p}"; sourceTree = SOURCE_ROOT; }};')

for p, fid in fixture_refs.items():
    name = os.path.basename(p)
    lines.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = "{p}"; sourceTree = SOURCE_ROOT; }};')

for p, fid in resource_refs.items():
    name = os.path.basename(p)
    ext = os.path.splitext(p)[1]
    ftype = {'': 'folder', '.plist': 'text.plist.xml', '.entitlements': 'text.plist.entitlements',
             '.json': 'text.json'}.get(ext, 'text')
    if '.xcassets' in p:
        ftype = 'folder.assetcatalog'
    lines.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = "{p}"; sourceTree = SOURCE_ROOT; }};')

lines.append('/* End PBXFileReference section */')

# ── PBXFrameworksBuildPhase ─────────────────────────────────────
lines.append('\n/* Begin PBXFrameworksBuildPhase section */')
lines.append(f'\t\t{APP_FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{')
lines.append(f'\t\t\tisa = PBXFrameworksBuildPhase;')
lines.append(f'\t\t\tbuildActionMask = 2147483647;')
lines.append(f'\t\t\tfiles = (')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append(f'\t\t}};')
lines.append(f'\t\t{TEST_FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{')
lines.append(f'\t\t\tisa = PBXFrameworksBuildPhase;')
lines.append(f'\t\t\tbuildActionMask = 2147483647;')
lines.append(f'\t\t\tfiles = (')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append(f'\t\t}};')
lines.append('/* End PBXFrameworksBuildPhase section */')

# ── PBXGroup ────────────────────────────────────────────────────
lines.append('\n/* Begin PBXGroup section */')
all_app_refs = list(file_refs.values()) + list(resource_refs.values())
lines.append(f'\t\t{MAIN_GROUP_ID} /* GeoBridge */ = {{')
lines.append(f'\t\t\tisa = PBXGroup;')
lines.append(f'\t\t\tchildren = (')
for ref in all_app_refs:
    lines.append(f'\t\t\t\t{ref},')
for ref in list(test_file_refs.values()) + list(fixture_refs.values()):
    lines.append(f'\t\t\t\t{ref},')
lines.append(f'\t\t\t\t{PRODUCTS_GROUP_ID},')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\tname = GeoBridge;')
lines.append(f'\t\t\tsourceTree = "<group>";')
lines.append(f'\t\t}};')
lines.append(f'\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{')
lines.append(f'\t\t\tisa = PBXGroup;')
lines.append(f'\t\t\tchildren = (')
lines.append(f'\t\t\t\t{APP_PRODUCT_REF_ID},')
lines.append(f'\t\t\t\t{TEST_PRODUCT_REF_ID},')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\tname = Products;')
lines.append(f'\t\t\tsourceTree = "<group>";')
lines.append(f'\t\t}};')
lines.append('/* End PBXGroup section */')

# ── PBXNativeTarget ─────────────────────────────────────────────
lines.append('\n/* Begin PBXNativeTarget section */')
lines.append(f'\t\t{APP_TARGET_ID} /* GeoBridge */ = {{')
lines.append(f'\t\t\tisa = PBXNativeTarget;')
lines.append(f'\t\t\tbuildConfigurationList = {CONFIG_LIST_APP_ID};')
lines.append(f'\t\t\tbuildPhases = (')
lines.append(f'\t\t\t\t{APP_SOURCES_PHASE_ID},')
lines.append(f'\t\t\t\t{APP_FRAMEWORKS_PHASE_ID},')
lines.append(f'\t\t\t\t{APP_RESOURCES_PHASE_ID},')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\tbuildRules = ();')
lines.append(f'\t\t\tdependencies = ();')
lines.append(f'\t\t\tname = GeoBridge;')
lines.append(f'\t\t\tproductName = GeoBridge;')
lines.append(f'\t\t\tproductReference = {APP_PRODUCT_REF_ID};')
lines.append(f'\t\t\tproductType = "com.apple.product-type.application";')
lines.append(f'\t\t}};')

lines.append(f'\t\t{TEST_TARGET_ID} /* GeoBridgeTests */ = {{')
lines.append(f'\t\t\tisa = PBXNativeTarget;')
lines.append(f'\t\t\tbuildConfigurationList = {CONFIG_LIST_TEST_ID};')
lines.append(f'\t\t\tbuildPhases = (')
lines.append(f'\t\t\t\t{TEST_SOURCES_PHASE_ID},')
lines.append(f'\t\t\t\t{TEST_FRAMEWORKS_PHASE_ID},')
lines.append(f'\t\t\t\t{TEST_RESOURCES_PHASE_ID},')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\tbuildRules = ();')
lines.append(f'\t\t\tdependencies = ({APP_TEST_DEPENDENCY_ID},);')
lines.append(f'\t\t\tname = GeoBridgeTests;')
lines.append(f'\t\t\tproductName = GeoBridgeTests;')
lines.append(f'\t\t\tproductReference = {TEST_PRODUCT_REF_ID};')
lines.append(f'\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
lines.append(f'\t\t}};')
lines.append('/* End PBXNativeTarget section */')

# ── PBXProject ──────────────────────────────────────────────────
lines.append('\n/* Begin PBXProject section */')
lines.append(f'\t\t{PROJECT_ID} /* Project object */ = {{')
lines.append(f'\t\t\tisa = PBXProject;')
lines.append(f'\t\t\tattributes = {{')
lines.append(f'\t\t\t\tBuildIndependentTargetsInParallel = 1;')
lines.append(f'\t\t\t\tLastSwiftUpdateCheck = 1500;')
lines.append(f'\t\t\t\tLastUpgradeCheck = 1500;')
lines.append(f'\t\t\t\tTargetAttributes = {{')
lines.append(f'\t\t\t\t\t{APP_TARGET_ID} = {{CreatedOnToolsVersion = 15.0;}};')
lines.append(f'\t\t\t\t\t{TEST_TARGET_ID} = {{CreatedOnToolsVersion = 15.0; TestTargetID = {APP_TARGET_ID};}};')
lines.append(f'\t\t\t\t}};')
lines.append(f'\t\t\t}};')
lines.append(f'\t\t\tbuildConfigurationList = {CONFIG_LIST_PROJECT_ID};')
lines.append(f'\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append(f'\t\t\tdevelopmentRegion = en;')
lines.append(f'\t\t\thasScannedForEncodings = 0;')
lines.append(f'\t\t\tknownRegions = (en, Base);')
lines.append(f'\t\t\tmainGroup = {MAIN_GROUP_ID};')
lines.append(f'\t\t\tproductsGroup = {PRODUCTS_GROUP_ID};')
lines.append(f'\t\t\tprojectDirPath = "";')
lines.append(f'\t\t\tprojectRoot = "";')
lines.append(f'\t\t\ttargets = ({APP_TARGET_ID}, {TEST_TARGET_ID},);')
lines.append(f'\t\t}};')
lines.append('/* End PBXProject section */')

# ── PBXResourcesBuildPhase ──────────────────────────────────────
lines.append('\n/* Begin PBXResourcesBuildPhase section */')
lines.append(f'\t\t{APP_RESOURCES_PHASE_ID} /* Resources */ = {{')
lines.append(f'\t\t\tisa = PBXResourcesBuildPhase;')
lines.append(f'\t\t\tbuildActionMask = 2147483647;')
lines.append(f'\t\t\tfiles = (')
for p, bid in resource_build_files.items():
    name = os.path.basename(p)
    lines.append(f'\t\t\t\t{bid} /* {name} in Resources */,')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append(f'\t\t}};')
lines.append(f'\t\t{TEST_RESOURCES_PHASE_ID} /* Resources */ = {{')
lines.append(f'\t\t\tisa = PBXResourcesBuildPhase;')
lines.append(f'\t\t\tbuildActionMask = 2147483647;')
lines.append(f'\t\t\tfiles = (')
for p, bid in fixture_build_files.items():
    name = os.path.basename(p)
    lines.append(f'\t\t\t\t{bid} /* {name} in Resources */,')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append(f'\t\t}};')
lines.append('/* End PBXResourcesBuildPhase section */')

# ── PBXSourcesBuildPhase ────────────────────────────────────────
lines.append('\n/* Begin PBXSourcesBuildPhase section */')
lines.append(f'\t\t{APP_SOURCES_PHASE_ID} /* Sources */ = {{')
lines.append(f'\t\t\tisa = PBXSourcesBuildPhase;')
lines.append(f'\t\t\tbuildActionMask = 2147483647;')
lines.append(f'\t\t\tfiles = (')
for p, bid in build_files.items():
    name = os.path.basename(p)
    lines.append(f'\t\t\t\t{bid} /* {name} in Sources */,')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append(f'\t\t}};')
lines.append(f'\t\t{TEST_SOURCES_PHASE_ID} /* Sources */ = {{')
lines.append(f'\t\t\tisa = PBXSourcesBuildPhase;')
lines.append(f'\t\t\tbuildActionMask = 2147483647;')
lines.append(f'\t\t\tfiles = (')
for p, bid in test_build_files.items():
    name = os.path.basename(p)
    lines.append(f'\t\t\t\t{bid} /* {name} in Sources */,')
lines.append(f'\t\t\t);')
lines.append(f'\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append(f'\t\t}};')
lines.append('/* End PBXSourcesBuildPhase section */')

# ── PBXTargetDependency ─────────────────────────────────────────
PROXY_ID = make_id()
lines.append('\n/* Begin PBXTargetDependency section */')
lines.append(f'\t\t{APP_TEST_DEPENDENCY_ID} = {{isa = PBXTargetDependency; target = {APP_TARGET_ID}; targetProxy = {PROXY_ID}; }};')
lines.append('/* End PBXTargetDependency section */')

lines.append('\n/* Begin PBXContainerItemProxy section */')
lines.append(f'\t\t{PROXY_ID} = {{')
lines.append(f'\t\t\tisa = PBXContainerItemProxy;')
lines.append(f'\t\t\tcontainerPortal = {PROJECT_ID};')
lines.append(f'\t\t\tproxyType = 1;')
lines.append(f'\t\t\tremoteGlobalIDString = {APP_TARGET_ID};')
lines.append(f'\t\t\tremoteInfo = GeoBridge;')
lines.append(f'\t\t}};')
lines.append('/* End PBXContainerItemProxy section */')

# ── XCBuildConfiguration ────────────────────────────────────────
def build_settings_app(config):
    return {
        'ALWAYS_SEARCH_USER_PATHS': 'NO',
        'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
        'CODE_SIGN_ENTITLEMENTS': 'GeoBridge/Resources/GeoBridge.entitlements',
        'CODE_SIGN_STYLE': 'Automatic',
        'COMBINE_HIDPI_IMAGES': 'YES',
        'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym' if config == 'Release' else 'dwarf',
        'ENABLE_HARDENED_RUNTIME': 'YES',
        'ENABLE_NS_ASSERTIONS': 'NO' if config == 'Release' else 'YES',
        'ENABLE_STRICT_OBJC_MSGSEND': 'YES',
        'GCC_C_LANGUAGE_STANDARD': 'gnu17',
        'GCC_NO_COMMON_BLOCKS': 'YES',
        'GCC_OPTIMIZATION_LEVEL': 's' if config == 'Release' else '0',
        'GCC_PREPROCESSOR_DEFINITIONS': '"DEBUG=1 $(inherited)"' if config == 'Debug' else '"$(inherited)"',
        'INFOPLIST_FILE': 'GeoBridge/Resources/Info.plist',
        'LD_RUNPATH_SEARCH_PATHS': '"$(inherited) @executable_path/../Frameworks"',
        'MACOSX_DEPLOYMENT_TARGET': '14.0',
        'MTL_ENABLE_DEBUG_INFO': 'INCLUDE_SOURCE' if config == 'Debug' else 'NO',
        'PRODUCT_BUNDLE_IDENTIFIER': 'dev.geobridge.app',
        'PRODUCT_NAME': '$(TARGET_NAME)',
        'SWIFT_COMPILATION_MODE': 'wholemodule' if config == 'Release' else 'incremental',
        'SWIFT_OPTIMIZATION_LEVEL': '-O' if config == 'Release' else '-Onone',
        'SWIFT_VERSION': '5.0',
    }

def build_settings_test(config):
    return {
        'BUNDLE_LOADER': '$(TEST_HOST)',
        'CODE_SIGN_STYLE': 'Automatic',
        'COMBINE_HIDPI_IMAGES': 'YES',
        'DEBUG_INFORMATION_FORMAT': 'dwarf',
        'ENABLE_TESTABILITY': 'YES',
        'GCC_C_LANGUAGE_STANDARD': 'gnu17',
        'MACOSX_DEPLOYMENT_TARGET': '14.0',
        'PRODUCT_BUNDLE_IDENTIFIER': 'dev.geobridge.tests',
        'PRODUCT_NAME': '$(TARGET_NAME)',
        'SWIFT_OPTIMIZATION_LEVEL': '-Onone',
        'SWIFT_VERSION': '5.0',
        'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/GeoBridge.app/Contents/MacOS/GeoBridge',
    }

def build_settings_project(config):
    return {
        'ALWAYS_SEARCH_USER_PATHS': 'NO',
        'CLANG_ANALYZER_NONNULL': 'YES',
        'CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING': 'YES',
        'CLANG_WARN_BOOL_CONVERSION': 'YES',
        'CLANG_WARN_CONSTANT_CONVERSION': 'YES',
        'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS': 'YES',
        'CLANG_WARN_DIRECT_OBJC_ISA_USAGE': 'YES_ERROR',
        'CLANG_WARN_EMPTY_BODY': 'YES',
        'CLANG_WARN_ENUM_CONVERSION': 'YES',
        'CLANG_WARN_INT_CONVERSION': 'YES',
        'CLANG_WARN_NON_LITERAL_NULL_CONVERSION': 'YES',
        'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF': 'YES',
        'CLANG_WARN_OBJC_LITERAL_CONVERSION': 'YES',
        'CLANG_WARN_OBJC_ROOT_CLASS': 'YES_ERROR',
        'CLANG_WARN_STRICT_PROTOTYPES': 'YES',
        'CLANG_WARN_UNREACHABLE_CODE': 'YES',
        'ENABLE_STRICT_OBJC_MSGSEND': 'YES',
        'GCC_C_LANGUAGE_STANDARD': 'gnu17',
        'GCC_WARN_64_TO_32_BIT_CONVERSION': 'YES',
        'GCC_WARN_ABOUT_RETURN_TYPE': 'YES_ERROR',
        'GCC_WARN_UNDECLARED_SELECTOR': 'YES',
        'GCC_WARN_UNINITIALIZED_AUTOS': 'YES_AGGRESSIVE',
        'GCC_WARN_UNUSED_FUNCTION': 'YES',
        'GCC_WARN_UNUSED_VARIABLE': 'YES',
        'MACOSX_DEPLOYMENT_TARGET': '14.0',
        'MTL_ENABLE_DEBUG_INFO': 'NO',
        'SDKROOT': 'macosx',
        'SWIFT_VERSION': '5.0',
    }

def emit_build_config(config_id, name, settings_fn, config):
    s = settings_fn(config)
    lines.append(f'\t\t{config_id} /* {name} */ = {{')
    lines.append(f'\t\t\tisa = XCBuildConfiguration;')
    lines.append(f'\t\t\tbuildSettings = {{')
    for k, v in s.items():
        lines.append(f'\t\t\t\t{k} = {v};')
    lines.append(f'\t\t\t}};')
    lines.append(f'\t\t\tname = {name};')
    lines.append(f'\t\t}};')

APP_DEBUG_ID = make_id()
APP_RELEASE_ID = make_id()
TEST_DEBUG_ID = make_id()
TEST_RELEASE_ID = make_id()
PROJ_DEBUG_ID = make_id()
PROJ_RELEASE_ID = make_id()

lines.append('\n/* Begin XCBuildConfiguration section */')
emit_build_config(APP_DEBUG_ID, 'Debug', build_settings_app, 'Debug')
emit_build_config(APP_RELEASE_ID, 'Release', build_settings_app, 'Release')
emit_build_config(TEST_DEBUG_ID, 'Debug', build_settings_test, 'Debug')
emit_build_config(TEST_RELEASE_ID, 'Release', build_settings_test, 'Release')
emit_build_config(PROJ_DEBUG_ID, 'Debug', build_settings_project, 'Debug')
emit_build_config(PROJ_RELEASE_ID, 'Release', build_settings_project, 'Release')
lines.append('/* End XCBuildConfiguration section */')

# ── XCConfigurationList ─────────────────────────────────────────
lines.append('\n/* Begin XCConfigurationList section */')
lines.append(f'\t\t{CONFIG_LIST_APP_ID} = {{')
lines.append(f'\t\t\tisa = XCConfigurationList;')
lines.append(f'\t\t\tbuildConfigurations = ({APP_DEBUG_ID}, {APP_RELEASE_ID},);')
lines.append(f'\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append(f'\t\t\tdefaultConfigurationName = Release;')
lines.append(f'\t\t}};')
lines.append(f'\t\t{CONFIG_LIST_TEST_ID} = {{')
lines.append(f'\t\t\tisa = XCConfigurationList;')
lines.append(f'\t\t\tbuildConfigurations = ({TEST_DEBUG_ID}, {TEST_RELEASE_ID},);')
lines.append(f'\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append(f'\t\t\tdefaultConfigurationName = Release;')
lines.append(f'\t\t}};')
lines.append(f'\t\t{CONFIG_LIST_PROJECT_ID} = {{')
lines.append(f'\t\t\tisa = XCConfigurationList;')
lines.append(f'\t\t\tbuildConfigurations = ({PROJ_DEBUG_ID}, {PROJ_RELEASE_ID},);')
lines.append(f'\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append(f'\t\t\tdefaultConfigurationName = Release;')
lines.append(f'\t\t}};')
lines.append('/* End XCConfigurationList section */')

lines.append('\t};')
lines.append(f'\trootObject = {PROJECT_ID} /* Project object */;')
lines.append('}')

# ── Write output ──────────────────────────────────────────────────────────────

xcodeproj_dir = os.path.join(ROOT, 'GeoBridge.xcodeproj')
os.makedirs(xcodeproj_dir, exist_ok=True)
pbxproj_path = os.path.join(xcodeproj_dir, 'project.pbxproj')

with open(pbxproj_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'Generated: {pbxproj_path}')
print(f'  App sources : {len(app_sources)} files')
print(f'  Test sources: {len(test_sources)} files')
print(f'  Resources   : {len(resource_files)} files')
print(f'  Fixtures    : {len(fixture_files)} files')
print()
print('Open in Xcode:')
print(f'  open {os.path.join(ROOT, "GeoBridge.xcodeproj")}')

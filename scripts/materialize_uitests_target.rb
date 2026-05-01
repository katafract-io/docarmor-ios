#!/usr/bin/env ruby
# Materialize the DocArmorUITests target properly.
#
# History: PR #80 (or earlier) added a PBXNativeTarget shell + a PBXFileReference
# + a PBXFileSystemSynchronizedRootGroup + a PBXContainerItemProxy for the test
# target — but NEVER created the build phases, XCConfigurationList, build configs,
# or the PBXTargetDependency that ties them together. xcodebuild ignored the
# orphan target as long as it wasn't in PBXProject.targets, but adding it (PR #91)
# crashed the parser.
#
# This script:
#   1. Removes the broken phantom DocArmorUITests target + its productReference
#      + its filesystem synchronized group + the orphan ContainerItemProxy.
#   2. Uses Xcodeproj::Project.new_target to create a real iOS UI test bundle
#      target with all PBX children Xcode would normally write.
#   3. Sets TEST_TARGET_NAME, BUNDLE_LOADER, TEST_HOST so the runner can launch
#      DocArmor.app and inject the test bundle.
#   4. Hooks the scheme: DocArmor.xcscheme TestAction.Testables already references
#      DocArmorUITests by Blueprint name, so the new target's UUID needs to match
#      the existing scheme refs OR we update the scheme. We pick: keep the scheme
#      stable (use the existing UUIDs F1A2B3C4D5E6F008A2B3C4D5 etc.) and rebuild
#      the target inside the existing slot.
#
require 'xcodeproj'

PROJECT_PATH = ARGV[0] || 'DocArmor.xcodeproj'
TEST_TARGET_NAME = 'DocArmorUITests'
HOST_TARGET_NAME = 'DocArmor'

proj = Xcodeproj::Project.open(PROJECT_PATH)

# Remove any existing target / file ref / synchronized group with the test name.
existing_target = proj.targets.find { |t| t.name == TEST_TARGET_NAME }
if existing_target
  puts "Removing existing target #{TEST_TARGET_NAME}…"
  existing_target.remove_from_project
end

# Remove any orphan PBXFileReference for DocArmorUITests.xctest (productReference)
proj.objects.select { |o| o.isa == 'PBXFileReference' && o.path == 'DocArmorUITests.xctest' }.each do |fr|
  puts "Removing orphan PBXFileReference #{fr.uuid}"
  fr.remove_from_project
end

# Remove any orphan PBXFileSystemSynchronizedRootGroup with path DocArmorUITests
proj.objects.select { |o| o.isa == 'PBXFileSystemSynchronizedRootGroup' && o.path == 'DocArmorUITests' }.each do |g|
  puts "Removing orphan PBXFileSystemSynchronizedRootGroup #{g.uuid}"
  g.remove_from_project
end

# Remove orphan ContainerItemProxy / TargetDependency entries pointing at DocArmorUITests
proj.objects.select { |o| o.isa == 'PBXContainerItemProxy' && o.remote_info == TEST_TARGET_NAME }.each do |p|
  puts "Removing orphan PBXContainerItemProxy #{p.uuid}"
  p.remove_from_project
end

# Find the host app target
host = proj.targets.find { |t| t.name == HOST_TARGET_NAME } or
  abort("Host target '#{HOST_TARGET_NAME}' not found")

# Create a real UI test target.
test_target = proj.new_target(:ui_test_bundle, TEST_TARGET_NAME, :ios, '17.0',
                              proj.products_group, :swift)

# Set bundle id + test target settings on every config
test_target.build_configurations.each do |cfg|
  cfg.build_settings['PRODUCT_NAME']             = TEST_TARGET_NAME
  cfg.build_settings['PRODUCT_MODULE_NAME']      = TEST_TARGET_NAME
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.katafract.DocArmor.DocArmorUITests'
  cfg.build_settings['TEST_TARGET_NAME']         = HOST_TARGET_NAME
  cfg.build_settings['CODE_SIGN_STYLE']          = 'Automatic'
  cfg.build_settings['SWIFT_VERSION']            = '5.0'
  cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  cfg.build_settings['TARGETED_DEVICE_FAMILY']   = '1,2'
  cfg.build_settings['GENERATE_INFOPLIST_FILE']  = 'YES'
  cfg.build_settings['CODE_SIGNING_ALLOWED']     = 'NO'
  cfg.build_settings['LD_RUNPATH_SEARCH_PATHS']  = '$(inherited) @executable_path/Frameworks @loader_path/Frameworks'
end

# Add the host as a target dependency
test_target.add_dependency(host)

# Wire DocArmorUITests/*.swift into the test target's Sources phase via a
# synchronized folder ref (Xcode 15+ PBXFileSystemSynchronizedRootGroup).
sync_group = proj.new(Xcodeproj::Project::Object::PBXFileSystemSynchronizedRootGroup)
sync_group.path = TEST_TARGET_NAME
sync_group.source_tree = '<group>'
proj.main_group << sync_group
test_target.file_system_synchronized_groups ||= []
test_target.file_system_synchronized_groups << sync_group

proj.save

# Sanity: print what we made
puts
puts "Created target: #{test_target.name} (uuid=#{test_target.uuid}, type=#{test_target.product_type})"
puts "Sources phase uuid: #{test_target.source_build_phase.uuid}"
puts "Frameworks phase uuid: #{test_target.frameworks_build_phase.uuid}"
puts "Resources phase uuid: #{test_target.resources_build_phase.uuid}"
puts "BuildConfigurationList uuid: #{test_target.build_configuration_list.uuid}"
puts "Synchronized root group uuid: #{sync_group.uuid}"

#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
require 'xcodeproj'

ROOT = Pathname.new(__dir__).parent.expand_path
PROJECT_PATH = ROOT + 'Fishbowl.xcodeproj'

FileUtils.rm_rf(PROJECT_PATH) if PROJECT_PATH.exist?

project = Xcodeproj::Project.new(PROJECT_PATH.to_s)
project.root_object.attributes['LastSwiftUpdateCheck'] = '2602'
project.root_object.attributes['LastUpgradeCheck'] = '2602'

app_target = project.new_target(:application, 'Fishbowl', :ios, '26.0')
widget_target = project.new_target(:app_extension, 'FishbowlWidgetExtension', :ios, '26.0')

project_group = project.main_group
fishbowl_group = project_group.new_group('Fishbowl', 'Fishbowl')
app_group = fishbowl_group.new_group('App', 'App')
shared_group = fishbowl_group.new_group('Shared', 'Shared')
fishbowl_group.new_file('Assets.xcassets')
widget_group = project_group.new_group('FishbowlWidgetExtension', 'FishbowlWidgetExtension')

app_sources = %w[
  FishbowlApp.swift
  ContentView.swift
].map { |path| app_group.new_file(path) }

shared_sources = %w[
  AquariumConfiguration.swift
  BowlProfileStore.swift
  LiquidGlassBackground.swift
  AquariumSceneView.swift
].map { |path| shared_group.new_file(path) }

widget_sources = %w[
  FishbowlWidgetBundle.swift
  FishbowlWidget.swift
].map { |path| widget_group.new_file(path) }

app_group.new_file('Info.plist')
app_group.new_file('Fishbowl.entitlements')
widget_group.new_file('Info.plist')
widget_group.new_file('FishbowlWidgetExtension.entitlements')

app_target.add_file_references(app_sources + shared_sources)
widget_target.add_file_references(widget_sources + shared_sources)
app_target.build_configurations.each do |config|
    settings = config.build_settings
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nate.fishbowl'
    settings['INFOPLIST_FILE'] = 'Fishbowl/App/Info.plist'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['SWIFT_VERSION'] = '6.0'
    settings['MARKETING_VERSION'] = '1.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
    settings['CODE_SIGN_ENTITLEMENTS'] = 'Fishbowl/App/Fishbowl.entitlements'
end

widget_target.build_configurations.each do |config|
    settings = config.build_settings
    settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.nate.fishbowl.widget'
    settings['INFOPLIST_FILE'] = 'FishbowlWidgetExtension/Info.plist'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['SWIFT_VERSION'] = '6.0'
    settings['MARKETING_VERSION'] = '1.0'
    settings['CURRENT_PROJECT_VERSION'] = '1'
    settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    settings['CODE_SIGN_STYLE'] = 'Automatic'
    settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
    settings['SKIP_INSTALL'] = 'YES'
    settings['SUPPORTED_PLATFORMS'] = 'iphoneos iphonesimulator'
    settings['CODE_SIGN_ENTITLEMENTS'] = 'FishbowlWidgetExtension/FishbowlWidgetExtension.entitlements'
end

project.build_configurations.each do |config|
    settings = config.build_settings
    settings['SWIFT_VERSION'] = '6.0'
    settings['TARGETED_DEVICE_FAMILY'] = '1,2'
    settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
end

app_target.add_dependency(widget_target)
embed_phase = app_target.new_copy_files_build_phase('Embed App Extensions')
embed_phase.symbol_dst_subfolder_spec = :plug_ins
embed_file = embed_phase.add_file_reference(widget_target.product_reference, true)
embed_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy', 'CodeSignOnCopy'] }

project.save
project.recreate_user_schemes
Xcodeproj::XCScheme.share_scheme(PROJECT_PATH, 'Fishbowl')
Xcodeproj::XCScheme.share_scheme(PROJECT_PATH, 'FishbowlWidgetExtension')

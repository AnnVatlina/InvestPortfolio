#!/usr/bin/env ruby
# Adds a unit test target "InvestPortfolioTests" to the Xcode project.

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'InvestPortfolio.xcodeproj')
TEST_TARGET_NAME = 'InvestPortfolioTests'
APP_TARGET_NAME  = 'InvestPortfolio'
BUNDLE_ID        = 'com.investportfolio.app.tests'
TEAM_ID          = 'SVVTWN6V74'

project = Xcodeproj::Project.open(PROJECT_PATH)

# Skip if already exists
if project.targets.any? { |t| t.name == TEST_TARGET_NAME }
  puts "Test target '#{TEST_TARGET_NAME}' already exists, skipping."
  exit 0
end

app_target = project.targets.find { |t| t.name == APP_TARGET_NAME }
raise "App target '#{APP_TARGET_NAME}' not found" unless app_target

# Create the unit test target
test_target = project.new_target(
  :unit_test_bundle,
  TEST_TARGET_NAME,
  :ios,
  '17.0'
)

# Link against the app target (host application)
test_target.add_dependency(app_target)

# Build settings shared for both configurations
shared_settings = {
  'SWIFT_VERSION'                       => '5.0',
  'PRODUCT_BUNDLE_IDENTIFIER'           => BUNDLE_ID,
  'DEVELOPMENT_TEAM'                    => TEAM_ID,
  'IPHONEOS_DEPLOYMENT_TARGET'          => '17.0',
  'TEST_HOST'                           => '$(BUILT_PRODUCTS_DIR)/InvestPortfolio.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/InvestPortfolio',
  'BUNDLE_LOADER'                       => '$(TEST_HOST)',
  'CODE_SIGN_STYLE'                     => 'Automatic',
  'GENERATE_INFOPLIST_FILE'             => 'YES',
  'SWIFT_EMIT_LOC_STRINGS'              => 'YES',
}

test_target.build_configurations.each do |config|
  shared_settings.each { |k, v| config.build_settings[k] = v }
end

# Create InvestPortfolioTests group in the project root
tests_group = project.main_group.new_group(TEST_TARGET_NAME, TEST_TARGET_NAME)

# Add test files to the group and to the target's sources phase
test_files = [
  'SubscriptionRepositoryTests.swift',
  'SubscriptionServiceTests.swift',
  'SubscriptionViewModelTests.swift',
]

test_files.each do |filename|
  file_ref = tests_group.new_reference(filename)
  test_target.source_build_phase.add_file_reference(file_ref)
end

project.save
puts "Test target '#{TEST_TARGET_NAME}' created successfully."

#!/usr/bin/env ruby
# Fixes PRODUCT_NAME in InvestPortfolioTests target build configurations.

require 'xcodeproj'

PROJECT_PATH = File.join(__dir__, 'InvestPortfolio.xcodeproj')
TEST_TARGET_NAME = 'InvestPortfolioTests'

project = Xcodeproj::Project.open(PROJECT_PATH)
test_target = project.targets.find { |t| t.name == TEST_TARGET_NAME }
raise "Target not found" unless test_target

test_target.build_configurations.each do |config|
  puts "Config: #{config.name}"
  puts "  PRODUCT_NAME before: #{config.build_settings['PRODUCT_NAME'].inspect}"
  config.build_settings['PRODUCT_NAME'] = TEST_TARGET_NAME
  puts "  PRODUCT_NAME after:  #{config.build_settings['PRODUCT_NAME'].inspect}"
end

project.save
puts "Done."

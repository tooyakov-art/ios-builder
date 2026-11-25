# Добавляет в Runner.xcodeproj UI-тест RunnerUITests (XCUITest) — только в копии проекта на раннере,
# в репо приложения ничего не коммитится. Гем xcodeproj — тот, что уже стоит на раннере вместе с CocoaPods.
# Запуск из папки ios приложения: ruby add_uitest_target.rb <папка simtest>
require 'fileutils'
require 'xcodeproj'

src = ARGV[0] or abort('нужна папка simtest')
project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
app = project.targets.find { |t| t.name == 'Runner' } or abort('нет таргета Runner')
abort('RunnerUITests уже есть') if project.targets.any? { |t| t.name == 'RunnerUITests' }

FileUtils.mkdir_p('RunnerUITests')
FileUtils.cp(File.join(src, 'PhoneFieldUITests.swift'), 'RunnerUITests/PhoneFieldUITests.swift')

ui = project.new_target(:ui_test_bundle, 'RunnerUITests', :ios, '15.0', nil, :swift)
group = project.main_group.new_group('RunnerUITests', 'RunnerUITests')
ui.add_file_references([group.new_reference('PhoneFieldUITests.swift')])
ui.add_dependency(app)
ui.build_configurations.each do |c|
  s = c.build_settings
  s['TEST_TARGET_NAME'] = 'Runner'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'kz.onetap.app.uitests'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['CODE_SIGN_STYLE'] = 'Automatic'
end
project.save

scheme_path = File.join(Xcodeproj::XCScheme.shared_data_dir(project_path), 'Runner.xcscheme')
scheme = Xcodeproj::XCScheme.new(scheme_path)
scheme.test_action.testables.each { |t| t.skipped = true } # шаблонный RunnerTests не гоняем
scheme.test_action.add_testable(Xcodeproj::XCScheme::TestAction::TestableReference.new(ui))
scheme.save_as(project_path, 'Runner', true)

puts "ok: RunnerUITests (#{ui.uuid}) в Runner.xcodeproj и схеме Runner"

require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

if target
  puts "Removing Sign in with Apple capability..."
  
  entitlements_path = 'Runner/Runner.entitlements'
  if File.exist?(entitlements_path)
    content = File.read(entitlements_path)
    # Remove the specific key and its value
    if content.include?('com.apple.developer.applesignin')
      puts "Entitlement found. Removing..."
      new_content = content.gsub(/<key>com\.apple\.developer\.applesignin<\/key>\s*<array>\s*<string>Default<\/string>\s*<\/array>/m, "")
      File.write(entitlements_path, new_content)
    end
  end
  
  # Also unset the build setting if needed, though usually just removing from entitlements is enough for build success
  # but Xcode might still complain if it's in the pbxproj as a capability.
  
  project.save
  puts "Sign in with Apple capability removal attempted."
else
  puts "Error: Runner target not found."
  exit 1
end

require 'xcodeproj'

project_path = 'Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

if target
  puts "Adding Sign in with Apple capability..."
  
  # Ensure the Entitlements file exists
  entitlements_path = 'Runner/Runner.entitlements'
  unless File.exist?(entitlements_path)
    File.write(entitlements_path, <<~PLIST)
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>com.apple.developer.applesignin</key>
        <array>
          <string>Default</string>
        </array>
      </dict>
      </plist>
    PLIST
    project.new_file(entitlements_path)
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
    end
  else
    # If exists, we should ideally use a plist library, but for simplicity:
    content = File.read(entitlements_path)
    unless content.include?('com.apple.developer.applesignin')
      # Very basic insertion before </dict>
      new_content = content.sub('</dict>', "  <key>com.apple.developer.applesignin</key>\n  <array>\n    <string>Default</string>\n  </array>\n</dict>")
      File.write(entitlements_path, new_content)
    end
  end
  
  project.save
  puts "Sign in with Apple capability added successfully."
else
  puts "Error: Runner target not found."
  exit 1
end

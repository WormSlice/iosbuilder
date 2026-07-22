require 'xcodeproj'

project_path = '/Users/duvanconde/Documents/proyectos/CONNECT/ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Runner target
target = project.targets.find { |t| t.name == 'Runner' }
group = project.main_group.find_subpath('Runner', false)

# Check if file is already in the project
file_ref = group.files.find { |f| f.path == 'GoogleService-Info.plist' }

unless file_ref
  # Add file reference to the group
  file_ref = group.new_file('GoogleService-Info.plist')
  
  # Add the file to the target's resources build phase
  target.resources_build_phase.add_file_reference(file_ref, true)
  
  project.save
  puts "Successfully linked GoogleService-Info.plist to the Xcode project."
else
  puts "GoogleService-Info.plist is already linked to the Xcode project."
end

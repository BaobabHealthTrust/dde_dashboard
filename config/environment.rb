# Load the Rails application.
require File.expand_path('../application', __FILE__)

APP_VERSION = `git describe`.gsub("\n","")

# Initialize the Rails application.
Rails.application.initialize!

# Initialize all views if not initialized

puts "Initializing views"

puts "People count : #{Person.all.count}"

puts "Npids count : #{Npid.all.count}"

puts "Connections count : #{Connection.all.count}"

puts "Footprints count : #{Footprint.all.count}"

puts "RequestsQues count : #{RequestsQue.all.count}"

puts "Sites count : #{Site.all.count}"

puts "Users count : #{User.all.count}"

if !File.exists?("#{Rails.root}/tmp/statuses")

  FileUtils.mkdir("#{Rails.root}/tmp/statuses")

end

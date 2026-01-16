begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "bundler/gem_tasks"

task :verify_release_branch do
  unless `git rev-parse --abbrev-ref HEAD`.chomp == "main"
    warn "Gem can only be released from the main branch"
    exit 1
  end
end

Rake::Task[:release].enhance([:verify_release_branch])

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: [:spec]

desc "Run the test application for manual testing"
task :test_app do
  exec "ruby test_app/run.rb"
end

namespace :test_app do
  desc "Stop the running test application"
  task :stop do
    # Find processes using port 9292 (the test app's web server)
    pids = `lsof -ti :9292`.split("\n").map(&:strip).reject(&:empty?)

    if pids.empty?
      puts "No running test application found (port 9292 is not in use)"
    else
      pids.each do |pid|
        puts "Killing process #{pid}..."
        system("kill #{pid}")
      end
      sleep 1
      puts "Test application stopped"
    end
  end
end

desc "Open an interactive console with test workers loaded"
task :console do
  exec "ruby test_app/console.rb"
end

task :benchmark do
  require_relative "benchmark"
end

# require "bundler/gem_tasks"
require "rspec/core/rake_task"

task :default => :spec

RSpec::Core::RakeTask.new

namespace :spec do
  desc "Run acceptance specs, calling AWS and servers"
  task :acceptance => %w[clean:vcr] do
    ENV['LIVE'] = '1'
    Rake::Task["spec"].invoke
  end
end

task :clean => %w[clean:vcr clean:reports]
namespace :clean do
  task :vcr do
    FileUtils.rm_rf('spec/fixtures/vcr_cassettes')
  end
  task :reports do
    FileUtils.rm_rf(Dir.glob('tmp/report*.txt'))
  end
end

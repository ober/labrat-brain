# require "bundler/gem_tasks"
require "rspec/core/rake_task"

task :default => :spec

RSpec::Core::RakeTask.new

namespace :spec do
  desc "Run acceptance specs"
  task :acceptance => %w[clean:vcr] do
    ENV['LIVE'] = "1"
    Rake::Task["spec"].invoke
  end
end

task :clean => %w[clean:chef_repo clean:vcr]
namespace :clean do
  task :env do
    ENV['TEST'] = '1'
    require "./lib/labrat_brain"
    @settings = Cfn::Settings.new.data
  end

  task :chef_repo => :env do
    chef_repo_path = File.dirname(@settings.rna_path)
    FileUtils.rm_rf(chef_repo_path)
  end

  desc "clean vcr_cassettes fixtures"
  task :vcr do
    FileUtils.rm_rf('spec/fixtures/vcr_cassettes')
  end
end

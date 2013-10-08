require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'rake'
require 'rspec'
require 'rspec/core/rake_task'

desc 'Default: run specs.'
task :default => :spec

RSpec::Core::RakeTask.new do |t|
  if ENV['COVERAGE'] and RUBY_VERSION =~ /^1.8/
    t.rcov = true
    t.rcov_opts = ['--exclude', 'spec', '--exclude', 'gems']
  end
end

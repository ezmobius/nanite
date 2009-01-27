require 'rubygems'
require 'rake/gempackagetask'
require "spec/rake/spectask"

GEM = "nanite"
VER = "0.2.0"
AUTHOR = "Ezra Zygmuntowicz"
EMAIL = "ezra@engineyard.com"
HOMEPAGE = "http://github.com/ezmobius/nanite"
SUMMARY = "self assembling fabric of ruby daemons"

Dir.glob('tasks/*.rake').each { |r| Rake.application.add_import r }

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = ::VER
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE", 'TODO']
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE

  s.bindir       = "bin"
  s.executables  = %w( nanite nanite-mapper nanite-admin )

  s.add_dependency "extlib"
  s.add_dependency('amqp', '>= 0.6.0')

  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc Rakefile TODO) + Dir.glob("{lib,bin,specs}/**/*")
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{VER}}
end

desc "Run unit specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ["--format", "specdoc", "--colour"]
  t.spec_files = FileList["spec/**/*_spec.rb"]
end

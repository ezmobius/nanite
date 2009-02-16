spec = Gem::Specification.new do |s|
  s.name = "nanite"
  s.version = "0.3.0"
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.rdoc", "LICENSE", 'TODO']
  s.summary = "self assembling fabric of ruby daemons"
  s.description = s.summary
  s.author = "Ezra Zygmuntowicz"
  s.email = "ezra@engineyard.com"
  s.homepage = "http://github.com/ezmobius/nanite"

  s.bindir       = "bin"
  s.executables  = %w( nanite-agent nanite-mapper nanite-admin )

  s.add_dependency "extlib"
  s.add_dependency('amqp', '>= 0.6.0')

  s.require_path = 'lib'
  s.files = %w(LICENSE README.rdoc Rakefile TODO) + Dir.glob("{lib,bin,specs}/**/*")
end

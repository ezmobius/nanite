spec = Gem::Specification.new do |s|
  s.name = 'nanite'
  s.version = '0.4.1.2'
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc', 'LICENSE', 'TODO']
  s.summary = 'self assembling fabric of ruby daemons'
  s.description = s.summary
  s.author = 'Ezra Zygmuntowicz'
  s.email = 'ezra@engineyard.com'
  s.homepage = 'http://github.com/ezmobius/nanite'

  s.bindir       = 'bin'
  s.executables  = [ 'nanite-agent', 'nanite-mapper', 'nanite-admin']

  s.add_dependency('amqp', '>= 0.6.0')

  s.require_path = 'lib'
  s.files = ['LICENSE', 'README.rdoc', 'Rakefile', 'TODO', 'lib/nanite.rb', 'lib/nanite', 'lib/nanite/streaming.rb', 'lib/nanite/serializer.rb', 'lib/nanite/pid_file.rb', 'lib/nanite/mapper.rb', 'lib/nanite/daemonize.rb', 'lib/nanite/mapper_proxy.rb', 'lib/nanite/security', 'lib/nanite/security/distinguished_name.rb', 'lib/nanite/security/secure_serializer.rb', 'lib/nanite/security/certificate_cache.rb', 'lib/nanite/security/signature.rb', 'lib/nanite/security/certificate.rb', 'lib/nanite/security/encrypted_document.rb', 'lib/nanite/security/rsa_key_pair.rb', 'lib/nanite/security/static_certificate_store.rb', 'lib/nanite/security/cached_certificate_store_proxy.rb', 'lib/nanite/config.rb', 'lib/nanite/util.rb', 'lib/nanite/log', 'lib/nanite/log/formatter.rb', 'lib/nanite/state.rb', 'lib/nanite/cluster.rb', 'lib/nanite/dispatcher.rb', 'lib/nanite/security_provider.rb', 'lib/nanite/packets.rb', 'lib/nanite/actor.rb', 'lib/nanite/console.rb', 'lib/nanite/admin.rb', 'lib/nanite/amqp.rb', 'lib/nanite/agent.rb', 'lib/nanite/local_state.rb', 'lib/nanite/identity.rb', 'lib/nanite/actor_registry.rb', 'lib/nanite/log.rb', 'lib/nanite/reaper.rb', 'lib/nanite/job.rb', 'bin/nanite-agent', 'bin/nanite-admin', 'bin/nanite-mapper', 'spec/util_spec.rb', 'spec/encrypted_document_spec.rb', 'spec/agent_spec.rb', 'spec/certificate_cache_spec.rb', 'spec/cached_certificate_store_proxy_spec.rb', 'spec/dispatcher_spec.rb', 'spec/rsa_key_pair_spec.rb', 'spec/cluster_spec.rb', 'spec/spec_helper.rb', 'spec/actor_registry_spec.rb', 'spec/actor_spec.rb', 'spec/packet_spec.rb', 'spec/local_state_spec.rb', 'spec/static_certificate_store_spec.rb', 'spec/job_spec.rb', 'spec/signature_spec.rb', 'spec/secure_serializer_spec.rb', 'spec/serializer_spec.rb', 'spec/certificate_spec.rb', 'spec/distinguished_name_spec.rb']
end

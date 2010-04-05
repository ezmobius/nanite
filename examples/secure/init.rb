# Configure secure serializer
certs_dir = File.join(File.dirname(__FILE__), 'certs')
mapper_cert = Nanite::Certificate.load(File.join(certs_dir, 'mapper_cert.pem'))
store = Nanite::StaticCertificateStore.new(mapper_cert, mapper_cert)
agent_cert = Nanite::Certificate.load(File.join(certs_dir, 'agent_cert.pem'))
agent_key = Nanite::RsaKeyPair.load(File.join(certs_dir, 'agent_key.pem'))
Nanite::SecureSerializer.init("agent", agent_cert, agent_key, store)

# Register actor
register Secure.new
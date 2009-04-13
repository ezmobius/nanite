module Nanite

  # Proxy to actual certificate store which caches results in an LRU
  # cache.
  class CachedCertificateStoreProxy
    
    # Initialize cache proxy with given certificate store.
    def initialize(store)
      @signer_cache = CertificateCache.new
      @store = store
    end
    
    # Results from 'get_recipients' are not cached
    def get_recipients(obj)
      @store.get_recipients(obj)
    end

    # Check cache for signer certificate
    def get_signer(id)
      @signer_cache.get(id) { @store.get_signer(id) }
    end

  end  
end

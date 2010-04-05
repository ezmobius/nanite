module Nanite
  # This class is used to interface the nanite mapper with an external security
  # module.
  # There are two points of integration:
  #  1. When an agent registers with a mapper
  #  2. When an agent sends a request to another agent 
  #
  # In both these cases the security module is called back and can deny the 
  # operation.
  # Note: it's the responsability of the module to do any logging or
  # notification that is required.
  class SecurityProvider
    
    # Register an external security module
    # This module should expose the 'authorize_registration' and 
    # 'authorize_request' methods.
    def self.register(mod)
      @security_module = mod
    end
    
    # Used internally by nanite to retrieve the current security module
    def self.get
      @security_module || default_security_module
    end
    
    # Default security module, authorizes all operations
    def self.default_security_module
      @default_sec_mod ||= DefaultSecurityModule.new
    end
    
  end
  
  # Default security module
  class DefaultSecurityModule
    
    # Authorize registration of agent (registration is an instance of Register)
    def authorize_registration(registration)
      true
    end
    
    # Authorize given inter-agent request (request is an instance of Request)
    def authorize_request(request)
      true
    end
    
  end
end
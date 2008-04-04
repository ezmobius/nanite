module Nanite
  class PackageManager
    def initialize(manager)
      @manager = manager
    end
    
    def install(pkg, version=nil)
      @manager.install(pkg, version)
    end
    
    def uninstall(pkg, version=nil)
      @manager.uninstall(pkg, version)
    end
    
    def installed?(pkg, version=nil)
      @manager.installed?(pkg, version)
    end
    
    def search(pkg, version=nil)
      @manager.search(pkg, version)
    end
    
  end  
end  
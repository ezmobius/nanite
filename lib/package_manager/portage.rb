module Nanite
  class Portage
    
    def initialize(flags=nil)
      @flags = flags
    end
  
    def install(pkg, version=nil)
      if version
        pkg = "=#{pkg}-#{version}"
      end
      sh "emerge #{@flags ? '-' + @flags.join : ''} #{pkg}"
    end
    
    def uninstall(pkg, version=nil)
      if version
        pkg = "=#{pkg}-#{version}"
      end
      sh "unmerge #{@flags ? '-' + @flags.join : ''} #{pkg}"
    end
    
    def installed?(pkg, version=nil)
      @manager.installed?(pkg, version)
    end
    
    def search(pkg, version=nil)
      @manager.search(pkg, version)
    end
    
  end  
end    
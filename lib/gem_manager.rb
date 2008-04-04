require "geminstaller" 

module Nanite
  class GemManager
    
    def initialize(cfg=File.expand_path("~/.nanite/geminstaller.yml"))
      @cfg = cfg
    end
    
    def sync_gems!
      GemInstaller.run("--config #{@cfg} --sudo --exceptions")
    end
  end
end    


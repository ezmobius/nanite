module Nanite

  # Implements a simple LRU cache: items that are the least accessed are
  # deleted first.
  class CertificateCache

    # Max number of items to keep in memory
    DEFAULT_CACHE_MAX_COUNT = 100

    # Initialize cache
    def initialize(max_count = DEFAULT_CACHE_MAX_COUNT)
      @items = {}
      @list = []
      @max_count = max_count
    end
    
    # Add item to cache
    def put(key, item)
      if @items.include?(key)
        delete(key)
      end
      if @list.size == @max_count
        delete(@list.first)
      end
      @items[key] = item
      @list.push(key)
      item
    end
    alias :[]= :put
    
    # Retrieve item from cache
    # Store item returned by given block if any
    def get(key)
      if @items.include?(key)
        @list.each_index do |i|
          if @list[i] == key
            @list.delete_at(i)
            break
          end
        end
        @list.push(key)
        @items[key]
      else
        return nil unless block_given?
         self[key] = yield
      end
    end
    alias :[] :get
    
    # Delete item from cache
    def delete(key)
      c = @items[key]
      if c
        @items.delete(key)
        @list.each_index do |i|
  	      if @list[i] == key
  	        @list.delete_at(i)
  	        break
  	      end
        end
        c
      end
    end

  end
end
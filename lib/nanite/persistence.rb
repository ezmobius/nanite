require 'rubygems'
require 'amalgalite'
require File.dirname(__FILE__) + '/../nanite'
module Nanite
  class MapperStore
    SCHEMA = <<-SQL
      create table agents(
        id integer primary key,
        name UNIQUE,
        resources
      );
    SQL
    
    SELECT     = 'select id, resources from agents where name=$name limit 1'
    SELECT_ALL = 'select name, resources from agents'
    DELETE     = 'delete from agents where name=$name'
    INSERT     = 'insert into agents(name, resources) values ($name, $resources)'
    
    def add_agent(name, resources)
      @db.transaction {
        @db.execute(INSERT, '$name' => name, '$resources' => marshal(resources))
      }
    rescue Amalgalite::SQLite3::Error => e
      p e
    end
    
    def update_agent(name, resources)
      @db.transaction {
        @db.execute(DELETE, '$name' => name)
        @db.execute(INSERT, '$name' => name, '$resources' => marshal(resources))
      }
    rescue Amalgalite::SQLite3::Error => e
      p e
    end
    
    def lookup_agent(name)
      row = @db.execute(SELECT, '$name' => name)[0]
      [row[0], unmarshal(row[1])]
    end
    
    def load_agents
      rows = @db.execute(SELECT_ALL)
      nanites = {}
      rows.each do |row|
        nanites[row[0]] = unmarshal(row[1])
      end  
      nanites
    end
    
    def delete_agent(name)
      @db.transaction {
        @db.execute(DELETE, '$name' => name)
      }
    end
      
    def inspect_agents
      rows = @db.execute('select * from agents')
      p rows
    end
  
    def initialize(path = default_path)
      @path = path
      setup!
    end
    
    def default_path
      "nanite.mapper.db"
    end
    
    def setup!
      @db = Amalgalite::Database.new @path
      unless @db.schema.tables['agents']
        @db.execute SCHEMA
        @db = Amalgalite::Database.new @path
      end
    end
  
    def marshal(string)
      [Marshal.dump(string)].pack('m*')
    end
    
    def unmarshal(str)
      Marshal.load(str.unpack("m")[0])
    end
  
  end

end  
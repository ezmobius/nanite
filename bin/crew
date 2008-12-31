#!/usr/bin/env ruby

agents = %w[tom jay edward yehuda james corey josh ezra womble jeff loren lance sam kevin kirk]

def process_exists?(str)
  result = `ps auwx | grep '#{str}' | grep -v grep | grep -v tail`
  !result.empty?
end

def run_agent(name, num, root)
  if !process_exists?(name)
    system("#{File.dirname(__FILE__)}/nanite -u #{name} -p testing -t #{name} -n #{root} -j &")
  end
end

agents.each_with_index do |a,idx|
  run_agent(a, idx, "/Users/ez/nanite/examples/rack-worker")
end


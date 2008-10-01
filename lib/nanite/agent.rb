
def stress(times, &blk)
  t = Time.now
  times.times do
    request('/mock/list', '', &blk)
  end
  puts Time.now - t
end

def request(type, payload, *resources, &blk)
  Nanite.request(type, payload, *resources, &blk)
end


def stress(times, &blk)
  t = Time.now
  times.times do
    op('list', '', '/mock', &blk)
  end
  puts Time.now - t
end

def op(type, payload, *resources, &blk)
  Nanite.op(type, payload, *resources, &blk)
end

class Clock < Nanite::Actor
  expose :time

  def time(payload)
    Time.now
  end
end

Nanite.register(Clock.new)

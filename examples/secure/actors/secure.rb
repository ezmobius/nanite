# Simple agent 
class Secure
  include Nanite::Actor
  expose :echo

  def echo(payload)
    "Nanite said #{payload.empty? ? "nothing at all" : payload} @ #{Time.now.to_s} *securely*"
  end
end

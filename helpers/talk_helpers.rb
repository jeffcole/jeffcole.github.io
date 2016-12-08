require "lib/talk"

module TalkHelpers
  def talks
    Talk.all(data.talks)
  end
end

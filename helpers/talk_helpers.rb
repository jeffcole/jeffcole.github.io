require "lib/talk"

module TalkHelpers
  def talks
    Talk.all(data.talks)
  end

  def talk_event(occurence)
    if occurence.event_url
      link_to occurence.event_name, occurence.event_url
    else
      occurence.event_name
    end
  end

  def talk_venue(occurence)
    if occurence.venue_url
      link_to occurence.venue_name, occurence.venue_url
    else
      occurence.venue_name
    end
  end

  def talk_slides(occurence)
    link_to "Slides", occurence.slides_url
  end

  def talk_video(occurence)
    link_to "Video", occurence.video_url
  end
end

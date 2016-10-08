require "lib/twitter_url"

module SocialHelpers
  def open_graph_type
    root? ? "profile" : "article"
  end

  def twitter_share_link(title)
    url = TwitterUrl.new(title, absolute_url).to_s

    link_to url, target: "_blank" do
      image_tag("/assets/images/icons/twitter.svg") +
        content_tag(:span) { "Tweet This" }
    end
  end
end

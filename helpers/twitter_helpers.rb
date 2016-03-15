module TwitterHelpers
  def twitter_share_link(title)
    url = TwitterUrl.new(title, absolute_url).to_s

    link_to url, target: "_blank" do
      image_tag("/assets/images/icons/twitter.svg") +
        content_tag(:span) { "Tweet this" }
    end
  end

  private

  class TwitterUrl
    attr_private_initialize :title, :absolute_url

    def to_s
      [base_url, query].join
    end

    private

    def base_url
      "http://twitter.com/home?"
    end

    def query
      { status: status }.to_query
    end

    def status
      "Read '#{title}' #{handle} #{absolute_url}"
    end

    def handle
      "@obscurehobo"
    end
  end
end

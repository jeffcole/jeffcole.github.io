module TwitterHelpers
  def twitter_share_link(page)
    url = TwitterUrl.new(page, config).to_s

    link_to url, target: "_blank" do
      image_tag("/assets/images/icons/twitter.svg") +
        content_tag(:span) { "Tweet this" }
    end
  end

  private

  class TwitterUrl
    attr_private_initialize :page, :config

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
      "Read '#{page.title}' #{handle} #{page_absolute_url}"
    end

    def page_absolute_url
      config.site.host + page.url
    end

    def handle
      "@obscurehobo"
    end
  end
end

module PageHelpers
  def absolute_url
    config.site.host + current_page.url
  end

  def page_title
    default_title = data.defaults.page_title

    if current_page.try(:title).present?
      "#{default_title} - #{current_page.title}"
    else
      default_title
    end
  end

  def meta_description
    current_page.data.meta_description.presence ||
      data.defaults.metadata.description
  end

  def meta_keywords
    current_page.data.meta_keywords.presence ||
      data.defaults.metadata.keywords
  end

  def root?
    current_page.url == "/"
  end
end

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
end

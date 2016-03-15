module PageHelpers
  def absolute_url
    config.site.host + current_page.url
  end
end

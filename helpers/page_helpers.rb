require "lib/external_link"

module PageHelpers
  def index_items
    (page_articles + ExternalLink.all(data.external_links)).
      sort_by(&:date).
      reverse
  end

  def title_and_date_link(article)
    link = article.try(:external?) ? article.url : article

    content_tag(:div, class: :info) do
      content_tag(:h3) { link_to(link) { article.title } }
    end +
      content_tag(:p, class: :date) { long_date(article.date) }
  end

  def long_date(date)
    date.strftime("%B %e, %Y")
  end

  def absolute_url
    config.site.host + current_page.url
  end

  def page_title
    default_title = data.defaults.page_title

    if current_page.data.try(:title).present?
      "#{default_title} - #{current_page.data.title}"
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

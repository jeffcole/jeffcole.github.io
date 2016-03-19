class ExternalLink
  attr_reader_initialize :date, :title, :url

  def self.all(data)
    data.map do |_, attributes|
      new(
        Date.parse(attributes[:date]), 
        attributes[:title],
        attributes[:url]
      )
    end
  end

  def external?
    true
  end
end

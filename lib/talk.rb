class Talk
  attr_reader_initialize :title, :occurrences

  def self.all(data)
    data.map do |_, attributes|
      new(
        attributes[:title],
        Occurrence.from_hash_list(attributes[:occurrences])
      )
    end
  end

  class Occurrence
    attr_reader_initialize :date, :event, :venue, :slides_url, :video_url

    def self.from_hash_list(list)
      list.map do |attributes|
        new(
          Date.parse(attributes[:date]),
          attributes[:event],
          attributes[:venue],
          attributes[:slides_url],
          attributes[:video_url]
        )
      end
    end
  end
end

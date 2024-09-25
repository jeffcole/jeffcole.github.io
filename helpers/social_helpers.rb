module SocialHelpers
  def open_graph_type
    root? ? "profile" : "article"
  end
end

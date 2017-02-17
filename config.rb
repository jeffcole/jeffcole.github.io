activate :autoprefixer
activate :pry
activate :syntax

set :relative_links, true
set :css_dir, "assets/stylesheets"
set :js_dir, "assets/javascripts"
set :images_dir, "assets/images"
set :fonts_dir, "assets/fonts"
set :layout, "application"

page "/*.xml", layout: false
page "/*.json", layout: false
page "/*.txt", layout: false

configure :development do
  activate :livereload

  config[:site] = OpenStruct.new(
    host: "http://localhost:4567"
  ).freeze
end

configure :build do
  activate :relative_assets

  config[:site] = OpenStruct.new(
    host: "https://jeffcole.github.io"
  ).freeze
end

activate :deploy do |deploy|
  deploy.build_before = true
  deploy.deploy_method = :git
  deploy.branch = "master"
  deploy.commit_message = ":shipit:"
end

activate :blog do |blog|
  # Matcher for blog source files
  blog.sources = "posts/{year}-{month}-{day}-{title}.html"

  blog.layout = "posts"
  blog.permalink = "{title}.html"
end

activate :directory_indexes

redirect "collaborative-music-loops-in-elixir-and-elm-the-back-end-part-1.html",
  to: "/collaborative-music-loops-in-elixir-and-elm/"

redirect "collaborative-music-loops-in-elixir-and-elm-the-back-end-part-2.html",
  to: "/talk-to-my-elixir-agent/"

redirect "collaborative-music-loops-in-elixir-and-elm-healthy-elixir-tests.html",
  to: "/testing-phoenix-sockets-and-channels/"

activate :directory_indexes
activate :autoprefixer
activate :pry

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
  # This will add a prefix to all links, template references and source paths
  blog.prefix = "blog"

  # Matcher for blog source files
  blog.sources = "posts/{year}-{month}-{day}-{title}.html"

  blog.layout = "blog"
  blog.permalink = "{title}.html"
end

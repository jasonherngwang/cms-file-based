require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, escape_html: true
end

root = File.expand_path("..", __FILE__)

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file_path)
  contents = File.read(file_path)

  case File.extname file_path
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  when ".md"
    # headers["Content-Type"] = "text/html;charset=utf-8"
    render_markdown(contents)
  end
end

get "/" do
  @files = Dir[root + "/data/*"]
           .select { |f| File.file? f }
           .map { |f| File.basename f }

  erb :index, layout: :layout
end

get "/:filename" do
  file_path = root + "/data/" + params[:filename]

  if File.file? file_path
    load_file_content(file_path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end
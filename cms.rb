# cms.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/flash'
require 'redcarpet'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    'test/data'
  else
    'data'
  end
end

helpers do
  def render_markdown(content)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
  end

  def get_files(directory)
    Dir.glob("#{directory}/*").map { |file| File.basename(file) }
  end
end

get '/' do
  @files = get_files(data_path)
  @files.sort!

  erb :index
end

get "/:filename" do
  filename = params['filename']
  @files = get_files(data_path)

  if @files.include?(filename)
    @file_content = File.read("#{data_path}/#{filename}")
    @file_content = render_markdown(@file_content) if filename.include?('.md')

    headers "Content-Type" => 'text/plain'
    erb :file, layout: false
  else
    session[:error] = "#{filename} does not exist."
    redirect "/"
  end
end

get "/edit/:filename" do
  @filename = params['filename']
  @files = get_files(data_path)

  if @files.include?(@filename)
    @file_content = File.read("#{data_path}/#{@filename}")

    erb :edit, layout: :layout
  else
    session[:error] = "#{@filename} does not exist."
    redirect "/"
  end
end

post "/edit/:filename" do
  File.write("#{data_path}/#{params['filename']}", params['content'])
  session[:success] = "#{params['filename']} was updated."
  redirect "/"
end

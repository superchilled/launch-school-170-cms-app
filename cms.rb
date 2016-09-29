# cms.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/flash'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

VALID_FILE_EXTENSIONS = ['txt', 'md']

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

def get_users
  users_file_path = if ENV["RACK_ENV"] == "test"
    "test/users.yml"
  else
    "users.yml"
  end
  YAML.load(File.read(users_file_path))
end

USERS = get_users

helpers do
  def render_markdown(content)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
  end

  def get_files(directory)
    Dir.glob("#{directory}/*").map { |file| File.basename(file) }
  end

  def signed_in?
    !!session[:username]
  end

  def validate_user_status
    return if signed_in?
    session[:error] = "You must be signed in to do that."
    redirect "/"
  end
end

get '/' do
  @files = get_files(data_path)
  @files.sort!

  erb :index
end

get "/new" do
  validate_user_status
  erb :new, layout: :layout
end

post "/new" do
  validate_user_status
  filename = params['filename'].to_s
  if filename.size == 0
    session[:error] = "A name is required."
    redirect "/new"
  elsif filename.split('.').size == 1
    session[:error] = "Filename requires an extension."
    redirect "/new"
  elsif filename.split('.').size > 2
    session[:error] = "Filename must not contain a '.'."
    redirect "/new"
  elsif !VALID_FILE_EXTENSIONS.include?(filename.split('.').last)
    session[:error] = "File extension invalid. Please use #{VALID_FILE_EXTENSIONS.join(', ')}"
    redirect "/new"
  else
    File.open(File.join(data_path, params['filename']), "w")
    session[:success] = "#{params['filename']} has been created."
    redirect "/"
  end
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
  validate_user_status
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
  validate_user_status
  File.write("#{data_path}/#{params['filename']}", params['content'])
  session[:success] = "#{params['filename']} was updated."
  redirect "/"
end

post "/delete/:filename" do
  validate_user_status
  File.delete("#{data_path}/#{params['filename']}")
  session[:success] = "#{params['filename']} was deleted."
  redirect "/"
end

get "/users/signin" do
  erb :signin, layout: :layout
end

post "/users/signin" do
  @username = params['username']
  password = params['password']
  if BCrypt::Password.new(USERS[@username]) == password
    session[:username] = @username
    session[:success] = "Welcome!"
    redirect "/"
  else
    session[:error] = "Invalid Credentials"
    erb :signin, layout: :layout
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:success] = "You have been signed out."
  redirect "/"
end

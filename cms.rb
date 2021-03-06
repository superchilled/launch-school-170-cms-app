# cms.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'sinatra/flash'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

VALID_FILE_EXTENSIONS = ['txt', 'md'].freeze

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

def image_path
  if ENV["RACK_ENV"] == "test"
    'test/images/'
  else
    'public/images/'
  end
end

def users_path
  if ENV["RACK_ENV"] == "test"
    'test/'
  else
    '/'
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

  def filename_error?(filename)
    if filename.size == 0
      "A name is required."
    elsif filename.split('.').size == 1
      "Filename requires an extension."
    elsif filename.split('.').size > 2
      "Filename must not contain a '.'."
    elsif !VALID_FILE_EXTENSIONS.include?(filename.split('.').last)
      "File extension invalid. Please use #{VALID_FILE_EXTENSIONS.join(', ')}"
    else
      false
    end
  end

  def run_git_sequence(filename, message)
    Dir.chdir(data_path) {
      system("git add #{filename}")
      system("git commit -m \'#{message}\'")
    }
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

get "/upload" do
  validate_user_status
  @filename = params['filename']
  @file_content = params['file_content']
  erb :upload, layout: :layout
end

post "/upload" do
  @file = params['file']
  @filename = params['filename']
  @images = get_files(image_path)
  @file_content = params['file_content']
  File.open(image_path + @file[:filename], "w") do |file|
    file.write(@file[:tempfile].read)
  end

  erb :edit, layout: :layout
end

post "/new" do
  validate_user_status
  filename = params['filename'].to_s
  filename_error = filename_error?(filename)
  if filename_error
    session[:error] = filename_error
    redirect "/new"
  else
    File.open(File.join(data_path, params['filename']), "w")
    session[:success] = "#{params['filename']} has been created."
    run_git_sequence(filename, "Adding file #{filename}")
    redirect "/"
  end
end

get "/duplicate" do
  validate_user_status
  @origin_filename = params['origin_filename']
  erb :duplicate, layout: :layout
end

post "/duplicate" do
  validate_user_status
  @origin_filename = params['origin_filename']
  new_filename = params['filename'].to_s
  filename_error = filename_error?(new_filename)
  if filename_error
    session[:error] = filename_error
    erb :duplicate, layout: :layout
  else
    file_content = File.read("#{data_path}/#{@origin_filename}")
    File.open(File.join(data_path, new_filename), "w")
    File.write("#{data_path}/#{new_filename}", file_content)
    session[:success] = "#{new_filename} has been created."
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
  @images = get_files(image_path)

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
  run_git_sequence(params['filename'], params['commit_message'])
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
  users = get_users
  if BCrypt::Password.new(users[@username]) == password
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

get "/users/signup" do
  erb :signup, layout: :layout
end

post "/users/signup" do
  username = params['username']
  password = BCrypt::Password.create(params['password'])
  File.open("#{users_path}users.yml", 'a') do |file|
    file.puts "#{username}: #{password}"
  end
  session[:username] = username
  session[:success] = "User account created. Welcome, #{username}!"
  redirect "/"
end

# cms.rb

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'

get '/' do
  @files = Dir.glob("data/*").map { |file| File.basename(file) }
  @files.sort!

  erb :index
end

get '/:filename' do
  filename = params['filename']
  @file_content = File.read("data/#{filename}")

  headers "Content-Type" => 'text/plain'
  erb :file, layout: false
end
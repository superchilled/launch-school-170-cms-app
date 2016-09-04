# cms_test.rb

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use!
require "rack/test"

require_relative "../cms.rb"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_index
    get "/"

    assert_equal 200, last_response.status
    assert last_response.body.include?("about.txt")
    assert last_response.body.include?("changes.txt")
    assert last_response.body.include?("history.txt")
  end

  def test_filepage
    get "/about.txt"

    assert_equal 200, last_response.status
    assert last_response.body.include?("This is a file-based CMS application built with Ruby and Sinatra.")
  end
end

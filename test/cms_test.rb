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

  def test_non_existent
    get "/nonexistent.txt"

    get last_response["Location"]

    assert_includes last_response.body, "nonexistent.txt does not exist."

    get "/"

    refute_includes last_response.body, "nonexistent.txt does not exist."
  end

  def test_markdown_rendering
    get "/markdown.md"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h1>This is a h1</h1>"
    assert_includes last_response.body, "<h2>This is a h2</h2>"
    assert_includes last_response.body, "<h3>This is a h3</h3>"
    assert_includes last_response.body, "<p>This is a paragraph</p>"
  end

  def test_edit_file
    get "/edit/markdown.md"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea># This is a h1"

    post "/edit/markdown.md"

    get last_response["Location"]

    assert_includes last_response.body, "markdown.md was updated."

    get "/"

    refute_includes last_response.body, "markdown.md was updated."
  end
end

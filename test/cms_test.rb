# cms_test.rb

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
Minitest::Reporters.use!
require "rack/test"
require "fileutils"

require_relative "../cms.rb"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.mkdir_p(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index
    create_document "about.txt"
    create_document "changes.txt"
    create_document "history.txt"

    get "/"

    assert_equal 200, last_response.status
    assert last_response.body.include?("about.txt")
    assert last_response.body.include?("changes.txt")
    assert last_response.body.include?("history.txt")
  end

  def test_filepage
    create_document "about.txt", "This is a file-based CMS application built with Ruby and Sinatra."

    get "/about.txt"

    assert_equal 200, last_response.status
    assert last_response.body.include?("This is a file-based CMS application built with Ruby and Sinatra.")
  end

  def test_non_existent
    # skip
    get "/nonexistent.txt"

    get last_response["Location"]

    assert_includes last_response.body, "nonexistent.txt does not exist."

    get "/"

    refute_includes last_response.body, "nonexistent.txt does not exist."
  end

  def test_markdown_rendering
    # skip
    create_document "markdown.md", "# This is a h1"
    get "/markdown.md"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<h1>This is a h1</h1>"
  end

  def test_edit_file
    # skip
    get "/edit/markdown.md"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea name=\"content\" cols=\"80\" rows=\"20\"># This is a h1"
  end

  def test_update_file
    # skip
    post "/edit/about.txt", content: "Some new content"

    get last_response["Location"]

    assert_includes last_response.body, "about.txt was updated."

    get "/"

    refute_includes last_response.body, "about.txt was updated."

    get "about.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Some new content"
  end
end

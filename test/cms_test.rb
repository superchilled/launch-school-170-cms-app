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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
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

    assert_equal "nonexistent.txt does not exist.", session[:error]

    get "/"

    refute_equal "nonexistent.txt does not exist.", session[:error]
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
    get "/edit/markdown.md", {}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get "/edit/markdown.md", {}, admin_session 

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea name=\"content\" cols=\"80\" rows=\"20\"># This is a h1"
  end

  def test_update_file
    # skip
    post "/edit/about.txt", { content: "Some new content" }
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    post "/edit/about.txt", { content: "Some new content" }, admin_session

    assert_equal "about.txt was updated.", session[:success]

    get "/"

    refute_equal "about.txt was updated.", session[:success]

    get "about.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Some new content"
  end

  def test_new_file
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<label for=\"filename\">New document name</label>"
    assert_includes last_response.body, "<button type=\"submit\">Create Document</button>"
  end

  def test_create_file
    post "/new", { filename: "somefile.md" }
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    post "/new", { filename: "somefile.md" }, admin_session 
    assert_equal "somefile.md has been created.", session[:success]
    get last_response["Location"]
    assert_includes last_response.body, "somefile.md"
    
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "somefile.md"
  end

  def test_no_filename
    post "/new", {}, admin_session
    assert_equal "A name is required.", session[:error]
  end

  def test_no_file_extension
    post "/new", { filename: "somefile" }, admin_session
    assert_equal "Filename requires an extension.", session[:error]
  end

  def test_dot_in_filename
    post "/new", { filename: "some.file.md" }, admin_session
    assert_equal "Filename must not contain a '.'.", session[:error]
  end

  def test_invalid_file_extension
    post "/new", { filename: "somefile.php" }, admin_session
    assert_equal "File extension invalid. Please use #{VALID_FILE_EXTENSIONS.join(', ')}", session[:error]
  end

  def test_duplicate
    get "/duplicate", { origin_filename: "somefile.txt" }, admin_session
    assert_includes last_response.body, "somefile.txt"
  end

  def test_duplicate_no_filename
    post "/duplicate", {}, admin_session
    assert_includes last_response.body, "A name is required."
  end

  def test_duplicate_no_file_extension
    post "/duplicate", { filename: "somefile" }, admin_session
    assert_includes last_response.body, "Filename requires an extension."
  end

  def test_duplicate_dot_in_filename
    post "/duplicate", { filename: "some.file.md" }, admin_session
    assert_includes last_response.body, "Filename must not contain a '.'."
  end

  def test_duplicate_invalid_file_extension
    post "/duplicate", { filename: "somefile.php" }, admin_session
    assert_includes last_response.body, "File extension invalid. Please use #{VALID_FILE_EXTENSIONS.join(', ')}", session[:error]
  end

  def test_duplicate_valid
    post "/duplicate", { origin_filename: "about.txt", filename: "some_file.md" }, admin_session
    assert_equal "some_file.md has been created.", session[:success]
  end

  def test_deletion_button
    create_document "delete_me.txt"
    get "/"
    assert_equal 200, last_response.status

    assert_includes last_response.body, "<a href=\"/delete_me.txt\">delete_me.txt</a>"
    assert_includes last_response.body, "<button type=\"submit\">Delete delete_me.txt</button>"
  end

  def test_deletion
    create_document "delete_me.txt"
    get "/"
    assert_equal 200, last_response.status

    assert_includes last_response.body, "<a href=\"/delete_me.txt\">delete_me.txt</a>"

    post "/delete/delete_me.txt"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:error]

    post "/delete/delete_me.txt", {}, admin_session 
    assert_equal 302, last_response.status
    assert_equal "delete_me.txt was deleted.", session[:success]

    get last_response["Location"]
    refute_includes "<a href=\"/delete_me.txt\">delete_me.txt</a>", last_response.body
  end

  def test_signin_button
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<button type=\"submit\">Sign In</button>"
    refute_includes last_response.body, "<button type=\"submit\">Sign Out</button>"
  end

  def test_signin_page
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input type=\"text\" name=\"username\""
    assert_includes last_response.body, "<input type=\"password\" name=\"password\">"
    assert_includes last_response.body, "<button type=\"submit\">Sign in</button>"
  end

  def test_valid_signin
    post "/users/signin", username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "admin", session[:username]
    get last_response["Location"]
    refute_includes "<button type=\"submit\">Sign In</button>", last_response.body
    assert_includes last_response.body, "You are signed in as admin"
    assert_includes last_response.body, "<button type=\"submit\">Sign Out</button>"
    
    get "/"
    refute_equal "Welcome!", session[:success]
  end

  def test_invalid_signin
    post "/users/signin", username: 'admin', password: 'wrong-secret'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input type=\"text\" name=\"username\""
    assert_includes last_response.body, "<input type=\"password\" name=\"password\">" 
    assert_includes last_response.body, "<button type=\"submit\">Sign in</button>"
    assert_includes last_response.body, "<p class=\"message\">Invalid Credentials</p>"
    assert_includes last_response.body, "<input type=\"text\" name=\"username\" value=\"admin\">"
  end

  def test_sign_out
    post "/users/signin", username: 'admin', password: 'secret'
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]

    post "/users/signout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:success]

    get "/"
    assert_includes last_response.body, "<button type=\"submit\">Sign In</button>"
  end

  def test_sign_up
    post "/users/signup", username: 'testuser', password: 'testpass'
    assert_equal 302, last_response.status
    assert_equal "User account created. Welcome, testuser!", session[:success]

    post "/users/signout"

    post "/users/signin", username: 'testuser', password: 'testpass'
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:success]
    assert_equal "testuser", session[:username]
  end
end

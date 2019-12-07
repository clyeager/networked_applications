ENV["RACK_ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'
require 'fileutils'

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra:: Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_file(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => {username: "admin" } }
  end

  def test_index
    create_file("about.md")
    create_file("changes.txt")

    get "/"

    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "about.md")
    assert_includes(last_response.body, "changes.txt")
  end

  def test_view_file
    create_file("history.txt", "Ruby 0.95 released")

    get "/history.txt"

    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "Ruby 0.95 released")
  end

  def test_file_not_found
    get "/notafile.ext"

    assert_equal(302, last_response.status)
    assert_equal("notafile.ext does not exist.", session[:message])
  end

  def test_markdown_files
    create_file("about.md", "<strong>What we are learning:</strong>")

    get "/about.md"

    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<strong>What we are learning:</strong>")
  end

  def test_editing_file
    create_file("changes.txt")

    get "/changes.txt/edit", {}, admin_session

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<textarea")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_editing_file_signed_out
    create_file("changes.txt")

    get "/changes.txt/edit"

    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_updating_file
    post "/changes.txt", {content: "new content"}, admin_session

    assert_equal(302, last_response.status)
    assert_equal("changes.txt has been updated.", session[:message])

    get "/changes.txt"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content")
  end

  def test_updating_file_signed_out
    post "/changes.txt", {content: "new content"}

    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_view_new_file_form
    get "/new", {}, admin_session

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<input")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_view_new_file_form_signed_out
    get "/new"

    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def create_new_file
    post "/create", {filename: "test.txt"}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("test.txt has been created", session[:message])

    get "/"
    assert_includes(last_response.body, "test.txt")
  end

  def create_new_file_signed_out
    post "/create", {filename: "test.txt"}
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_create_new_file_without_name
    post "/create", {filename: ""}, admin_session
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "A name is required")
  end

  def test_deleting_file
    create_file("test.txt")

    post "/test.txt/delete", {}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("test.txt has been deleted", session[:message])

    get "/"
    refute_includes(last_response.body, %q(href="/test.txt"))
  end

  def test_deleting_file_signed_out
    create_file("test.txt")

    post "/test.txt/delete"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_signin_form
    get "/users/signin"

    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "<input")
    assert_includes(last_response.body, %q(<button type="submit"))
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal(302, last_response.status)
    assert_equal("Welcome!", session[:message])
    assert_equal("admin", session[:username])

    get last_response["Location"]
    assert_includes(last_response.body, "Signed in as admin")
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Invalid credentials")
    assert_nil(session[:username])
  end

  def test_signout
    get "/", {}, admin_session
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    assert_equal "You have been signed out", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end
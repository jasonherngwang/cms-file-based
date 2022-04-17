ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "rack/test"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def signin(user, password)
    post "/users/signin", user: user, password: password
  end

  def test_index
    create_document "about.md"
    create_document "about.txt"
    
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    
    # Search entire HTML string for file names.
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "about.txt"
  end
  
  def test_view_text_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"
  end
    
  def test_view_markdown_document
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_document_not_found
    get "/a.txt"

    assert_equal 302, last_response.status
    
    # Follow the redirect.
    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "a.txt does not exist."
    
    # Check that error goes away after reload.
    get "/"
    refute_includes last_response.body, "a.txt does not exist."
  end

  def test_editing_document
    signin("admin", "secret")

    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt/edit"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "button type=\"submit\""
  end

  def test_updating_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    post "/about.txt", content: "New content"
    
    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.txt has been updated."

    # Check that the changes persisted.
    get "/about.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "New content"
  end

  def test_add_document_form
    signin("admin", "secret")

    get "/new"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Add a new document:"
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, "<button type=\"submit\""
  end

  def test_invalid_document_name
    signin("admin", "secret")

    post "/new", filename: ""

    assert_equal 422, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "A name is required."
  end

  def test_added_document
    signin("admin", "secret")

    post "/new", filename: "newdocument.txt"

    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "newdocument.txt was created."

    get "/"
    assert_includes last_response.body, "newdocument.txt"
  end

  def test_delete_document
    signin("admin", "secret")

    create_document "delete_me.txt"

    post "/delete_me.txt/delete"

    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "delete_me.txt was deleted."
    
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    refute_includes last_response.body, "delete_me.txt"
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Username:"
    assert_includes last_response.body, %q(<input name="user")
    assert_includes last_response.body, "Password:"
    assert_includes last_response.body, %q(<input name="password")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def text_signin_process
    signin("admin", "secret")

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "Welcome!"

    get "/"

    refute_includes last_response.body, "Welcome!"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    
    assert_includes last_response.body, %q(Signed in as admin.)
    assert_includes last_response.body, %q(<button>Sign Out</button></form>)
  end

  def test_edit_blocked_before_signin
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt/edit"

    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Username:"
    assert_includes last_response.body, %q(<input name="user")
    assert_includes last_response.body, "Password:"
    assert_includes last_response.body, %q(<input name="password")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_new_blocked_before_signin
    get "/new"

    assert_equal 302, last_response.status

    get last_response["Location"]
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Username:"
    assert_includes last_response.body, %q(<input name="user")
    assert_includes last_response.body, "Password:"
    assert_includes last_response.body, %q(<input name="password")
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_index_not_signed_in
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
    refute_includes last_response.body, %q(/edit">Edit</a>)
    refute_includes last_response.body, %q(<button type="submit">Delete</button>)
  end
  
  def test_signin_empty_invalid
    signin("", "secret")

    assert_equal 422, last_response.status

    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Username and/or password cannot be empty."
    
    signin("abc", "")
    assert_includes last_response.body, "Username and/or password cannot be empty."
    
    signin("abc", "def")
    assert_includes last_response.body, "Invalid Credentials."
  end

  def test_signout
    signin("admin", "secret")
    get last_response["Location"]
    assert_includes last_response.body, "Welcome"

    post "/users/signout"
    get last_response["Location"]

    assert_includes last_response.body, "You have been signed out."
    assert_includes last_response.body, "Sign In"
  end
end

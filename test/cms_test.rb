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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => { user: "admin" } }
  end


  def test_index
    create_document "about.md"
    create_document "about.txt"
    
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "about.txt"
  end

  def test_index_not_signed_in
    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    
    assert_includes last_response.body, %q(<a href="/users/signin">Sign In</a>)
    refute_includes last_response.body, %q(/edit">Edit</a>)
    refute_includes last_response.body, %q(<button type="submit">Delete</button>)
  end
  
  def test_viewing_text_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"
  end
    
  def test_viewing_markdown_document
    create_document "about.md", "# Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_document_not_found
    get "/a.txt"

    assert_equal 302, last_response.status
    assert_equal "a.txt does not exist.", session[:message]
  end

  def test_editing_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(button type="submit")
  end

  def test_edit_blocked_before_signin
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    get "/about.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    post "/about.txt", { content: "New content" }, admin_session
    assert_equal "about.txt has been updated.", session[:message]
    
    get "/about.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "New content"
  end

  def test_update_blocked_before_signin
    create_document "about.txt", "Ruby is an interpreted, high-level, "\
      "general-purpose programming language"

    post "/about.txt", { content: "New content" }

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Add a new document:"
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_form_blocked_before_signin
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_add_new_document
    post "/new", { filename: "newdocument.txt" }, admin_session

    assert_equal 302, last_response.status
    assert_equal "newdocument.txt was created.", session[:message]

    get "/"
    assert_includes last_response.body, "newdocument.txt"
  end

  def test_add_new_blocked_before_signin
    post "/new", { filename: "newdocument.txt" }

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
  
  def test_empty_document_name
    post "/new", { filename: "" }, admin_session

    assert_equal 422, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "A name is required."
  end

  def test_delete_document
    create_document "delete_me.txt"

    post "/delete_me.txt/delete", {}, admin_session

    assert_equal 302, last_response.status
    assert_equal "delete_me.txt was deleted.", session[:message]

    get "/"

    assert_equal 200, last_response.status
    refute_includes last_response.body, %(href="/delete_me.txt")
  end

  def test_delete_document_blocked_before_signin
    create_document "delete_me.txt"

    post "/delete_me.txt/delete"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
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

  def test_signin_process
    post "/users/signin", { user: "admin", password: "secret" }

    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:user]

    get last_response["Location"]

    assert_equal 200, last_response.status    
    assert_includes last_response.body, %q(Signed in as admin.)
    assert_includes last_response.body, %q(<button>Sign Out</button>)
  end

  def test_signin_invalid_credentials
    post "/users/signin", { user: "", password: "secret" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username and/or password cannot be empty."
    
    post "/users/signin", { user: "admin", password: "" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username and/or password cannot be empty."
    
    post "/users/signin", { user: "a", password: "s" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid Credentials."
  end

  def test_signout
    get "/", {}, admin_session

    post "/users/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]

    assert_nil session[:user]
    assert_includes last_response.body, "Sign In"
  end
end

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a user to test login. This assumes your User model
    # has 'username' and 'password' attributes.
    @user = User.create!(
      username: "Lain",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  # --- Rendering Tests ---

  test "should get login page" do
    get login_path # Assumes 'new' is routed to /login
    assert_response :success
    assert_select "form" # Ensures the login form is present
  end

  # --- Login Logic Tests ---

  test "should login with valid credentials" do
    # This tests the 'create' action
    post login_path, params: { username: @user.username, password: "password123" }

    # Verify session is set and user is redirected
    assert_redirected_to root_path
    assert_equal @user.id, session[:user_id]

    follow_redirect!
    assert_match "Logged in as #{@user.username}", response.body
  end

  test "should not login with invalid credentials" do
    # Attempt login with a wrong password
    post login_path, params: { username: @user.username, password: "wrong_password" }

    # Verify failure behavior: unprocessable_entity and nil session
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_match "Invalid credentials", response.body
  end

  # --- Logout Logic Tests ---

  test "should logout and clear session" do
    # First, perform a manual login to set the session
    post login_path, params: { username: @user.username, password: "password123" }
    assert_not_nil session[:user_id]

    # Perform logout
    delete logout_path # Assumes 'destroy' is routed to /logout

    # Verify session is cleared and redirect includes see_other status
    assert_nil session[:user_id]
    assert_redirected_to root_path
    assert_response :see_other

    follow_redirect!
    assert_match "You have been logged out", response.body
  end
end
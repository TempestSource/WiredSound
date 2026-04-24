require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_params = {
      user: {
        username: "NewUser",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
    }
  end

  # --- Rendering Tests ---

  test "should get new" do
    get signup_path # Or however you've named the route for registrations#new
    assert_response :success
    assert_select "form", 1 # Verifies the signup form is actually on the page
  end

  # --- Creation Logic Tests ---

  test "should create user and set session" do
    assert_difference "User.count", 1 do
      post registrations_path, params: @user_params
    end

    # 1. Verify Redirection
    assert_redirected_to root_path
    follow_redirect!
    assert_match "Welcome to WiredSound", response.body

    # 2. Verify Session logic
    assert_equal session[:user_id], User.last.id
  end

  test "should not create user with mismatched passwords" do
    invalid_params = @user_params
    invalid_params[:user][:password_confirmation] = "wrongpassword"

    assert_no_difference "User.count" do
      post registrations_path, params: invalid_params
    end

    # Verifies the unprocessable_entity status
    assert_response :unprocessable_entity
    # Check if the form re-rendered (looking for the form tag again)
    assert_select "form"
  end

  test "should not create user with missing username" do
    invalid_params = @user_params
    invalid_params[:user][:username] = ""

    assert_no_difference "User.count" do
      post registrations_path, params: invalid_params
    end

    assert_response :unprocessable_entity
  end
end
require "test_helper"
require "tmpdir" # Allows us to create safe, temporary folders for testing

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get settings_url
    assert_response :success
  end

  test "should successfully update incoming_path if directory is real" do
    # Create a temporary directory that is guaranteed to exist
    Dir.mktmpdir do |temp_dir|
      patch settings_url, params: { incoming_path: temp_dir }

      assert_redirected_to settings_path
      assert_equal "Listener successfully updated to #{temp_dir}", flash[:notice]

      # Verify it actually saved to the database
      setting = SystemSetting.find_by(key: 'incoming_path')
      assert_equal temp_dir, setting.value
    end
  end

  test "should reject update if directory does not exist" do
    fake_path = "/this/path/is/completely/fake/12345"

    patch settings_url, params: { incoming_path: fake_path }

    assert_redirected_to settings_path
    assert_equal "Invalid Directory Path: The directory does not exist or is restricted.", flash[:alert]
  end
end
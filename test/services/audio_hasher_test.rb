require "test_helper"

class AudioHasherTest < ActiveSupport::TestCase
  def setup
    @temp_file = Tempfile.new("test_song")
    @temp_file.write("This is some dummy music data")
    @temp_file.rewind
  end

  def teardown
    @temp_file.close
    @temp_file.unlink
  end

  test "generates correct md5 hash for existing file" do
    expected_hash = "2d7daa7326f5b2fa3d11a761227be87b"

    result = AudioHasher.call(@temp_file.path)

    assert_equal expected_hash, result
  end

  test "returns nil for non-existent file" do
    result = AudioHasher.call("fake/path/golden.mp3")
    assert_nil result
  end
end
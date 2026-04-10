require "test_helper"
require "ostruct"

class MetadataHelperTest < ActiveSupport::TestCase
  setup do
    # A reusable mock object that pretends to be a successful HTTParty response
    @mock_response = OpenStruct.new(success?: true)
  end

  test "search_by_filename rejects a match with a score below 85" do
    @mock_response.body = <<-XML
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#" xmlns:ext="http://musicbrainz.org/ns/ext#-2.0">
        <recording ext:score="50" id="bad-match-123">
          <title>Random Garbage</title>
        </recording>
      </metadata>
    XML

    HTTParty.stub :get, @mock_response do
      result = MetadataHelper.search_by_filename("some random query")
      assert_nil result, "Should return nil for scores under 85"
    end
  end

  test "search_by_filename rejects generic 'Sound Effect' matches" do
    @mock_response.body = <<-XML
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#" xmlns:ext="http://musicbrainz.org/ns/ext#-2.0">
        <recording ext:score="100" id="sound-effect-123">
          <title>Sound Effect</title>
        </recording>
      </metadata>
    XML

    HTTParty.stub :get, @mock_response do
      result = MetadataHelper.search_by_filename("whoosh cinematic")
      assert_nil result, "Should reject literal 'Sound Effect' if deskulling isn't in query"
    end
  end

  test "get_album_info successfully extracts track number and date" do
    @mock_response.body = <<-XML
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
        <recording>
          <release id="album-123">
            <title>Test Album</title>
            <date>2026-05-15</date>
            <medium-list>
              <medium>
                <track-list>
                  <track><number>7</number></track>
                </track-list>
              </medium>
            </medium-list>
          </release>
        </recording>
      </metadata>
    XML

    HTTParty.stub :get, @mock_response do
      result = MetadataHelper.get_album_info("recording-123")
      assert_equal "album-123", result[:album_id]
      assert_equal "Test Album", result[:album_name]
      assert_equal "2026-05-15", result[:release_date]
      assert_equal "7", result[:track_number]
    end
  end
end
require "test_helper"
require "nokogiri"
require_relative "../../app/metadata" # Force Rails to load your specific file!

class MetadataTest < ActiveSupport::TestCase
  setup do
    @metadata = Metadata.new
  end

  test "process_song correctly parses song title and artist data" do
    # 1. Create the XML strings exactly as MusicBrainz returns them
    song_xml = <<-XML
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
        <recording id="song-123">
          <title>Awesome Track</title>
        </recording>
      </metadata>
    XML

    artist_xml = <<-XML
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
        <artist id="art-123" type="Group">
          <name>The Band</name>
          <country>US</country>
          <begin>2010</begin>
        </artist>
      </metadata>
    XML

    # 2. Intercept HTTParty.get and return a simple object that responds to .to_s
    # This perfectly mimics how your request() method calls response.to_s
    mock_response = Struct.new(:body) do
      def to_s
        body
      end
    end

    HTTParty.stub :get, ->(url, *) {
      if url.include?("recording/")
        mock_response.new(song_xml)
      else
        mock_response.new(artist_xml)
      end
    } do

      result = @metadata.process_song("song-123")

      assert_equal "song-123", result[0]
      assert_equal "Awesome Track", result[1]

      artist_data = result[2].first
      assert_equal "art-123", artist_data[0]
      assert_equal "Group", artist_data[1]
      assert_equal "The Band", artist_data[2]
      assert_equal "US", artist_data[3]
    end
  end
end
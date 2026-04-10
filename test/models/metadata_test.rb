require "test_helper"
require "nokogiri"

class MetadataTest < ActiveSupport::TestCase
  setup do
    @metadata = Metadata.new
  end

  test "process_song correctly parses song title and artist data" do
    # 1. Mock the song title response
    song_xml = Nokogiri::XML(<<-XML)
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
        <recording id="song-123"><title>Awesome Track</title></recording>
      </metadata>
    XML

    # 2. Mock the artist linked request response
    artist_xml = Nokogiri::XML(<<-XML)
      <metadata xmlns="http://musicbrainz.org/ns/mmd-2.0#">
        <artist id="art-123" type="Group">
          <name>The Band</name>
          <country>US</country>
          <begin>2010</begin>
        </artist>
      </metadata>
    XML

    # Use Mocha/Minitest to intercept the internal network calls
    @metadata.stub :request, song_xml do
      @metadata.stub :linked_request, artist_xml do

        result = @metadata.process_song("song-123")

        # Format expected: [song_id, title, [ [art_id, type, name, country, begin] ]]
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
end
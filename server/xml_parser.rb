# frozen_string_literal: true

require 'nokogiri'

class XmlParser

  def parse(raw)
    xml = Nokogiri::XML(raw.to_s)
    puts(xml)
  end
  
end

require 'spec/spec_helper'

module KDL
  class Page
    def initialize(mets, identifier, dip_directory)
      @mets = mets
      @identifier = identifier
      @dip_directory = dip_directory
    end

    def page_fields
      hash = {}
      [
        :page_number,
        :sequence_number,
        :text_href,
        :text,
      ].each do |page_field|
        hash[page_field] = send(page_field)
      end
      hash
    end

    def sequence_number
      @mets.sequence_number @identifier
    end

    def page_number
      @mets.page_number @identifier
    end

    def text
      IO.read(File.join(@dip_directory, 
                        'data', 
                        text_href))
    end

    def text_href
      @mets.text_href @identifier
    end
  end
end

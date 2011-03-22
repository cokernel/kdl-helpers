require 'spec/spec_helper'

module KDL
  class Page
    def initialize(mets, identifier, dip_directory, solr_doc)
      @mets = mets
      @identifier = identifier
      @dip_directory = dip_directory
      @solr_doc = solr_doc
    end

    def page_fields
      [
        :id,
        :page_number,
        :sequence_number,
        :text,
      ].each do |page_field|
        @solr_doc[page_field] = send(page_field)
      end
      @solr_doc
    end

    def id
      "#{@identifier}_#{sequence_number}"
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

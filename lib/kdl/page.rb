require 'spec/spec_helper'

module KDL
  class Page
    attr_reader :identifier

    def initialize(mets, identifier, dip_directory, solr_doc)
      @mets = mets
      @identifier = identifier
      @dip_directory = dip_directory
      @solr_doc = solr_doc
    end

    def save(solr_directory)
      FileUtils.mkdir_p(solr_directory)
      solr_file = File.join(solr_directory, @identifier)
      File.open(solr_file, 'w') { |f|
        f.write page_fields.to_json
      }
    end

    def page_fields
      [
        :id,
        :page_number_display,
        :sequence_number_display,
        :text,
      ].each do |page_field|
        @solr_doc[page_field] = send(page_field)
      end
      @solr_doc
    end

    def id
      "#{@identifier}_#{sequence_number_display}"
    end

    def sequence_number_display
      @mets.sequence_number @identifier
    end

    def page_number_display
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

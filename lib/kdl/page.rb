require 'spec/spec_helper'

module KDL
  class Page
    def initialize(mets, identifier)
      @mets = mets
      @identifier = identifier
    end

    def page_fields
      hash = {}
      [
        :page_number,
        :sequence_number,
        :text_href,
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

    def text_href
      @mets.text_href @identifier
    end
  end
end

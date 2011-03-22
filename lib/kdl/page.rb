require 'spec/spec_helper'

module KDL
  class Page
    def initialize(mets, identifier)
      @mets = mets
      @identifier = identifier
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

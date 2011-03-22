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
  end
end

require 'spec/spec_helper'

module KDL
  class MetsFixer
    attr_reader :mets

    def initialize(mets_file)
      @mets_file = mets_file
      @mets = KDL::METS.new
      @mets.load(@mets_file)
    end
  end
end

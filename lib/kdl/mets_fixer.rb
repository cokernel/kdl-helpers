require 'spec/spec_helper'

module KDL
  class MetsFixer
    attr_reader :mets

    def initialize(mets_file)
      @mets_file = mets_file
      @mets = KDL::METS.new
      @mets.load(@mets_file)
    end

    def has_bad_file_ids(fileGrp_id)
      result = false
      @mets.file(:fileGrp => fileGrp_id).each do |file|
        expected_id = @mets.file_id_for file['USE'], fileGrp_id
        got_id = file['ID']
        if !(got_id == expected_id)
          return true
        end
      end
      result
    end
  end
end

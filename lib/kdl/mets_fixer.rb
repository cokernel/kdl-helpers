require 'kdl/mets'

module KDL
  class MetsFixer
    attr_reader :mets

    def initialize(mets_file)
      @mets_file = mets_file
      @mets = KDL::METS.new
      @mets.load(@mets_file)
    end

    def fix_all
      @mets.ids.each do |id|
        fix(id)
      end
      save
    end

    def save
      # @mets.save makes a backup copy.
      # We have to do the real save here
      @mets.save
      File.open(@mets_file, 'w') do |f|
        @mets.mets.write_xml_to f
      end
    end

    def fix(fileGrp_id)
      @mets.file(:fileGrp => fileGrp_id).each do |file|
        use = file['USE']
        got_id = file['ID']
        expected_id = @mets.file_id_for use, fileGrp_id
        if !(got_id == expected_id)
          fptr = @mets.mets.xpath("//mets:div/mets:fptr[@FILEID='#{got_id}']").first
          fptr['FILEID'] = expected_id
          file['ID'] = expected_id
          @mets.mark_changed
        end
      end
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

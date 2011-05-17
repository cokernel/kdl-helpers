require 'spec_helper'

module KDL
  describe MetsFixer do
    let (:mets_src) { File.join('data', 'mets', 'mets-bad-ids.xml') }
    let (:playground) { File.join('data', 'playground') }
    let (:mets_file) { File.join(playground, 'mets.xml') }

    before (:each) do
      FileUtils.mkdir_p(playground)
      FileUtils.cp mets_src, mets_file
      @mets_fixer = KDL::MetsFixer.new(mets_file)
    end

    after (:each) do
      FileUtils.rm_rf(playground)
    end

    it "loads a METS file" do
      @mets_fixer.mets.class.should == KDL::METS
    end

    describe "#has_bad_file_ids" do
      it "detects problems with files in a mets:fileGrp" do
        @mets_fixer.has_bad_file_ids('FileGrp002').should be_true
      end

      it "does not detect problems where they do not exist" do
        @mets_fixer.has_bad_file_ids('FileGrp001').should be_false
      end
    end

    describe "#fix" do
      it "repairs bad ids in the indicated fileGrp" do
        @mets_fixer.has_bad_file_ids('FileGrp002').should be_true
        @mets_fixer.fix('FileGrp002')
        @mets_fixer.has_bad_file_ids('FileGrp002').should be_false
      end

      it "marks the METS file as changed if it makes a change" do
        @mets_fixer.mets.should_not be_changed
        @mets_fixer.fix('FileGrp002')
        @mets_fixer.mets.should be_changed
      end
    end

    describe "#fix_all" do
      it "repairs all ids" do
        @mets_fixer.fix_all
        @mets_fixer.mets.ids.each do |id|
          @mets_fixer.has_bad_file_ids(id).should be_false
        end
      end

      it "saves the fixed METS file" do
        @mets_fixer.mets.should_receive(:save)
        @mets_fixer.fix_all
      end
    end
  end
end

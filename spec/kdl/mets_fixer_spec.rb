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
  end
end

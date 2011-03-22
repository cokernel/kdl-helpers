require 'spec_helper'

module KDL
  describe Page do
    context "Page-specific metadata" do
      describe "#sequence_number" do
        it "delegates to METS" do
          mets = double('mets').as_null_object
          identifier = 'MasterFileGrp0001'
          page = Page.new mets, identifier
          mets.should_receive(:sequence_number)
          page.sequence_number
        end
      end
    end
  end
end

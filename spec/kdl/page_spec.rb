require 'spec_helper'

module KDL
  describe Page do
    context "Page-specific metadata" do
      [
        :sequence_number,
        :page_number,
      ].each do |page_field| 
        describe "#{page_field}" do
          it "delegates to METS" do
            mets = double('mets').as_null_object
            identifier = 'MasterFileGrp0001'
            page = Page.new mets, identifier
            mets.should_receive(page_field)
            page.send(page_field)
          end
        end
      end
    end
  end
end

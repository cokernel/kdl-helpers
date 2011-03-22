require 'spec_helper'

module KDL
  describe Page do
    let(:mets) { double('mets').as_null_object }
    let(:identifier) { 'FileGrp0001' }
    let(:dips_directory) { File.join('data', 'dips') }
    let(:dip_id) { 'sample_aip' }
    let(:dip_directory) { File.join(dips_directory, dip_id) }
    let(:page) { Page.new mets, identifier, dip_directory }

    context "Export" do
      describe "#page_fields" do
        it "creates a hash of fields common to all pages" do
          page.stub(:text).and_return('howdy')
          [
            :page_number,
            :sequence_number,
            :text,
          ].each do |page_field|
            page.page_fields.should have_key(page_field)
          end
        end
      end
    end

    context "Page-specific metadata" do
      [
        :page_number,
        :sequence_number,
        :text_href,
      ].each do |page_field| 
        describe "#{page_field}" do
          it "delegates to METS" do
            mets.should_receive(page_field)
            page.send(page_field)
          end
        end
      end

      describe "#text" do
        it "retrieves the text from the DIP directory" do
          mets = METS.new
          mets.load File.join(dip_directory, 'data', 'mets.xml')
          page = Page.new mets, identifier, dip_directory
          file = File.join(dip_directory, 'data', page.text_href)
          page.text.should == IO.read(file)
        end
      end
    end
  end
end

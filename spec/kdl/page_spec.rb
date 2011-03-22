require 'spec_helper'

module KDL
  describe Page do
    let(:mets) { double('mets').as_null_object }
    let(:identifier) { 'FileGrp0001' }
    let(:dips_directory) { File.join('data', 'dips') }
    let(:dip_id) { 'sample_aip' }
    let(:dip_directory) { File.join(dips_directory, dip_id) }
    let(:page) { Page.new mets, identifier, dip_directory, Hash.new }
    let(:playground) { File.join('data', 'playground') }
    let(:solrs_directory) { File.join(playground, 'solr') }
    let(:solr_directory) { File.join(solrs_directory, dip_id) }

    context "Export" do
      describe "#save" do
        before(:each) do
          FileUtils.mkdir_p(solr_directory)
        end

        after(:each) do
          FileUtils.rm_rf(playground)
        end

        it "serializes page_fields to a JSON file in the specified directory" do
          mets = METS.new
          mets.load File.join(dip_directory, 'data', 'mets.xml')
          page = Page.new mets, identifier, dip_directory, Hash.new
          page.save solr_directory
          File.file?(File.join(solr_directory, page.identifier)).should be_true
        end
      end

      describe "#page_fields" do
        it "creates a hash of fields common to all pages" do
          page.stub(:text).and_return('howdy')
          [
            :id,
            :page_number_display,
            :sequence_number_display,
            :text,
          ].each do |page_field|
            page.page_fields.should have_key(page_field)
          end
        end
      end
    end

    context "Page-specific metadata" do
      [
        :page_number_display,
        :sequence_number_display,
        :text_href,
      ].each do |page_field| 
        describe "#{page_field}" do
          it "delegates to METS" do
            mets_field = page_field.to_s.sub(/_display/, '').to_sym
            mets.should_receive(mets_field)
            page.send(page_field)
          end
        end
      end

      describe "#id" do
        it "constructs an identifier for an individual page" do
          expected = "#{identifier}_#{page.sequence_number_display}"
          page.id.should == expected
        end
      end

      describe "#text" do
        it "retrieves the text from the DIP directory" do
          mets = METS.new
          mets.load File.join(dip_directory, 'data', 'mets.xml')
          page = Page.new mets, identifier, dip_directory, Hash.new
          file = File.join(dip_directory, 'data', page.text_href)
          page.text.should == IO.read(file)
        end
      end
    end
  end
end

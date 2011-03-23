require 'spec_helper'

module KDL
  describe Page do
    let(:mets) { double('mets').as_null_object }
    let(:identifier) { 'FileGrp0001' }
    let(:identifier_p2) { 'FileGrp0002' }
    let(:dips_directory) { File.join('data', 'dips') }
    let(:dip_id) { 'sample_aip' }
    let(:dip_directory) { File.join(dips_directory, dip_id) }
    let (:solr_doc) {{
            :author_t => 'foo',
            :author_display => 'foo',
            :title_t => 'foo',
            :title_display => 'foo',
            :description_t => 'foo',
            :description_display => 'foo',
            :subject_topic_facet => 'foo',
            :date_facet => 'foo',
            :language_facet => 'foo',
            :usage_display => 'foo',
            :publisher_t => 'foo',
            :publisher_display => 'foo',
            :parent_id_s => 'foo',
            :repository_t => 'foo',
            :repository_display => 'foo',
            :date_digitized_display => 'foo',
            :format_facet => 'foo',
            :type_display => 'foo',
            :relation_display => 'foo',
            }}
    let(:page) { Page.new mets, identifier, dip_id, dip_directory, solr_doc }
    let(:page_specific_fields) { [
            :id,
            :label_display,
            :sequence_number_display,
            :text,
            ]}
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
          page = Page.new mets, identifier, dip_id, dip_directory, Hash.new
          page.save solr_directory
          File.file?(File.join(solr_directory, page.id)).should be_true
        end
      end

      describe "#page_type" do
        it "delegates to METS" do
          mets.should_receive(:page_type)
          page.page_type
        end
      end

      describe "#page_fields" do
        it "creates a hash of fields common to all pages" do
          page.stub(:text).and_return('howdy')
          page_specific_fields.each do |page_field|
            page.page_fields.should have_key(page_field)
          end
        end

        it "includes all solr_doc fields for the first page" do
          page.stub(:sequence_number_display).and_return(1)
          page.stub(:text).and_return('howdy')
          [
            :author_t,
            :author_display,
            :title_t,
            :title_display,
            :description_t,
            :description_display,
            :subject_topic_facet,
            :date_facet,
            :language_facet,
            :usage_display,
            :publisher_t,
            :publisher_display,
            :parent_id_s,
            :repository_t,
            :repository_display,
            :date_digitized_display,
            :format_facet,
            :type_display,
            :relation_display,
          ].each do |solr_field| 
            page.page_fields.should have_key(solr_field)
          end 
        end

        it "only includes specified fields for subsequent pages" do
          page = Page.new mets, identifier_p2, dip_id, dip_directory, solr_doc
          page.stub(:text).and_return('howdy')
          whitelist = [
            :title_t,
            :title_display,
            :language_facet,
            :usage_display,
            :parent_id_s,
            :relation_display,
            :repository_display,
          ]
          whitelist.each do |solr_field| 
            page.page_fields.should have_key(solr_field)
          end 
          page.page_fields.length.should == whitelist.length + page_specific_fields.length
        end

        it "includes an abbreviated title for subsequent pages" do
          page = Page.new mets, identifier_p2, dip_id, dip_directory, solr_doc
          page.stub(:page_type).and_return('page')
          page.stub(:sequence_number_display).and_return('2')
          page.stub(:label_display).and_return('2')
          page.stub(:text).and_return('howdy')
          page.page_fields[:title_t].should_not be_nil
          page.page_fields[:title_t].should == 'Page 2'
          page.page_fields[:title_display].should == 'Page 2'
        end
      end
    end

    context "Page-specific metadata" do
      [
        :label_display,
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
          expected = "#{dip_id}_#{page.sequence_number_display}"
          page.id.should == expected
        end
      end

      describe "#text" do
        it "retrieves the text from the DIP directory" do
          mets = METS.new
          mets.load File.join(dip_directory, 'data', 'mets.xml')
          page = Page.new mets, identifier, dip_id, dip_directory, Hash.new
          file = File.join(dip_directory, 'data', page.text_href)
          page.text.should == IO.read(file)
        end
      end
    end
  end
end

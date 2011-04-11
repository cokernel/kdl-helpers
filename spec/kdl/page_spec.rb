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
            :title_sort => 'foo',
            :description_t => 'foo',
            :description_display => 'foo',
            :subject_topic_facet => 'foo',
            :pub_date => 'foo',
            :language_display => 'foo',
            :usage_display => 'foo',
            :publisher_t => 'foo',
            :publisher_display => 'foo',
            :parent_id_s => 'foo',
            :repository_facet => 'foo',
            :repository_display => 'foo',
            :date_digitized_display => 'foo',
            :format => 'foo',
            :type_display => 'foo',
            :relation_display => 'foo',
            :mets_url_display => 'foo',
            }}
    let(:page) { Page.new mets, identifier, dip_id, dip_directory, solr_doc }
    let(:page_specific_fields) { [
            :id,
            :label_display,
            :sequence_number_display,
            :sequence_sort,
            :text,
            :text_s,
            :reference_image_url_s,
            :pdf_url_display,
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
          page.stub(:sequence_number_display).and_return('1')
          page_specific_fields.each do |page_field|
            page.page_fields.should have_key(page_field)
          end
        end

        it "includes all solr_doc fields for the first page" do
          page.stub(:sequence_number_display).and_return(1)
          page.stub(:page_type).and_return('page')
          page.stub(:label_display).and_return('1')
          page.stub(:text).and_return('howdy')
          page.solr_doc.keys.each do |solr_field|
            page.page_fields.should have_key(solr_field)
          end
          page.page_fields[:title_display].should == "Page 1 of #{solr_doc[:title_t]}"
        end

        it "only includes specified fields for subsequent pages" do
          page = Page.new mets, identifier_p2, dip_id, dip_directory, solr_doc
          page.stub(:text).and_return('howdy')
          page.stub(:sequence_number_display).and_return(2)
          whitelist = [
            :title_t,
            :title_display,
            :title_sort,
            :format,
            :language_display,
            :usage_display,
            :parent_id_s,
            :relation_display,
            :repository_display,
            :viewer_url_s,
            :mets_url_display,
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
          page.page_fields[:title_display].should == "Page 2 of #{solr_doc[:title_t]}"
        end

        it "includes a modified title for subsequent pages of type 'sequence'" do
          page = Page.new mets, identifier_p2, dip_id, dip_directory, solr_doc
          page.stub(:page_type).and_return('sequence')
          page.stub(:sequence_number_display).and_return('3')
          page.stub(:label_display).and_return('2')
          page.stub(:text).and_return('howdy')
          page.page_fields[:title_t].should_not be_nil
          page.page_fields[:title_t].should == 'Sequence 2'
          page.page_fields[:title_display].should == "Sequence 3 of #{solr_doc[:title_t]}"
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

      describe "#parent_id_s" do
        it "strikes the last _\d+ group from the identifier" do
          probable_parent = 'identifier_1_1_2'
          id = "#{probable_parent}_3"
          page.stub(:id).and_return(id)
          page.parent_id_s.should == probable_parent
        end
      end

      describe "#pdf_url_display" do
        it "partially delegates to METS" do
          mets.stub(:print_image_path).and_return('0001/0001.pdf')
          mets.should_receive(:print_image_path)
          page.pdf_url_display.should == "http://nyx.uky.edu/dips/#{dip_id}/data/0001/0001.pdf"
        end
      end

      describe "#reference_image_url_s" do
        it "partially delegates to METS" do
          mets.stub(:reference_image_path).and_return('66M37_1_01/0001/0001.jpg')
          mets.should_receive(:reference_image_path)
          page.reference_image_url_s.should == "http://nyx.uky.edu/dips/#{dip_id}/data/66M37_1_01/0001/0001.jpg"
        end
      end

      describe "#viewer_url_s" do
        it "partially delegates to METS" do
          mets.stub(:viewer_path).and_return('0001/0001.txt')
          mets.should_receive(:viewer_path)
          page.viewer_url_s.should == "http://nyx.uky.edu/dips/#{dip_id}/data/0001/0001.txt"
        end
      end

      describe "#page_identifier" do
        it "partially delegates to METS" do
          mets.stub(:order_path).and_return(['1', '1', '2', '3'])
          mets.should_receive(:order_path)
          page.page_identifier.should == '1_1_2_3'
        end
      end

      describe "#sequence_sort" do
        it "is a zero-padded version of sequence_number_display" do
          page.stub(:sequence_number_display).and_return('1')
          number = page.sequence_number_display
          page.sequence_sort.should == '00001'
        end
      end

      describe "#id" do
        it "constructs an identifier for an individual page" do
          page.stub(:page_identifer).and_return('1_1_2_3')
          expected = "#{dip_id}_#{page.page_identifier}"
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

      describe "#text_s" do
        it "delegates to text" do
          mets = METS.new
          mets.load File.join(dip_directory, 'data', 'mets.xml')
          page = Page.new mets, identifier, dip_id, dip_directory, Hash.new
          file = File.join(dip_directory, 'data', page.text_href)
          page.should_receive(:text)
          page.text_s
        end
      end
    end
  end
end

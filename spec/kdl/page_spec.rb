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
            :repository_facet => 'foo',
            :repository_display => 'foo',
            :date_digitized_display => 'foo',
            :format => 'foo',
            :type_display => 'foo',
            :relation_display => 'foo',
            :mets_url_display => 'foo',
            :coverage_s => 'foo',
            :source_s => 'foo',
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
            :thumbnail_url_s,
            :front_thumbnail_url_s,
            :pdf_url_display,
            :parent_id_s,
            :coordinates_s,
            :browse_key_sort,
            ]}
    let(:full_sample_solr_doc) {
      hash = solr_doc.dup
      hash[:title_processed_s] = 'foo'
      hash
    }
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
          page = Page.new mets, identifier, dip_id, dip_directory, full_sample_solr_doc
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
        before(:each) do
          @xml = Nokogiri::XML IO.read(File.join('data', 'mets', '66M37.dao.xml'))
        end

        it "creates a hash of fields common to all pages" do
          page.stub(:finding_aid_xml).and_return(@xml)
          page.stub(:text).and_return('howdy')
          page.stub(:sequence_number_display).and_return('1')
          page.stub(:coordinates_s).and_return('')
          page_specific_fields.each do |page_field|
            page.page_fields.should have_key(page_field)
          end
        end

        it "includes all solr_doc fields for all pages" do
          page.stub(:finding_aid_xml).and_return(@xml)
          page.stub(:page_type).and_return('page')
          page.stub(:text).and_return('howdy')
          page.stub(:coordinates_s).and_return('')
          (1..2).each do |number|
            page.stub(:label_display).and_return(number.to_s)
            page.stub(:sequence_number_display).and_return(number)
            page.solr_doc.keys.each do |solr_field|
              page.page_fields.should have_key(solr_field)
            end
            mets.stub(:label_path).and_return([number.to_s])
            page.page_fields[:title_display].should == "Page #{number} of #{solr_doc[:title_sort]}"
          end
        end

        it "includes a breadcrumb trail in title_display when possible" do
          FileUtils.mkdir_p File.join(playground, 'mets')
          mets_src = File.join('data', 'mets', 'mets2.xml')
          mets_file = File.join(playground, 'mets', 'mets2.xml')
          FileUtils.cp mets_src, mets_file
          mets = KDL::METS.new
          mets.load mets_file
          page = Page.new mets, 'FileGrp1_1_002_0003', dip_id, dip_directory, solr_doc
          page.stub(:finding_aid_xml).and_return(@xml)
          page.stub(:page_type).and_return('page')
          page.stub(:sequence_number_display).and_return('3')
          page.stub(:text).and_return('howdy')
          page.page_fields[:title_display].should == "I. Correspondence, 1839-1893 > 1 > General to Anna Cooper, [11 February 1858]-11 September 1865 > Page 3 of #{solr_doc[:title_sort]}"
          page.page_fields[:title_t].should == page.page_fields[:title_display]
        end

        it "includes a minimal title when label is text" do
          FileUtils.mkdir_p File.join(playground, 'mets')
          mets_src = File.join('data', 'mets', 'mets4.xml')
          mets_file = File.join(playground, 'mets', 'mets4.xml')
          FileUtils.cp mets_src, mets_file
          mets = KDL::METS.new
          mets.load mets_file
          page = Page.new mets, 'FileGrp08c7c134d60c307c3b41b448039b80df', dip_id, dip_directory, solr_doc
          page.stub(:finding_aid_xml).and_return(@xml)
          page.stub(:page_type).and_return('page')
          page.stub(:sequence_number_display).and_return('3')
          page.stub(:text).and_return('howdy')
          page.stub(:page_type).and_return('item')
          page.stub(:label_display).and_return('&quot;American Liberty League&quot; Statement by Jouett Shouse at the time of the announcement of the formation of this organization, August 23, 1934., ;!')
          page.page_fields[:title_display].should == '&quot;American Liberty League&quot; Statement by Jouett Shouse at the time of the announcement of the formation of this organization, August 23, 1934'
          page.page_fields[:title_t].should == page.page_fields[:title_display]
        end

        it "includes a restricted set of fields for finding aid pages" do
          FileUtils.mkdir_p File.join(playground, 'mets')
          mets_src = File.join('data', 'mets', 'mets2.xml')
          mets_file = File.join(playground, 'mets', 'mets2.xml')
          FileUtils.cp mets_src, mets_file
          mets = KDL::METS.new
          mets.load mets_file
          page = Page.new mets, 'FileGrpFindingAid', dip_id, dip_directory, full_sample_solr_doc, true
          page.page_fields.should_not be_nil
          wanted_keys = [
            :id,
            :title_display,
            :title_guide_display,
            :title_t,
            :text,
            :text_s,
          ]
          wanted_keys.each do |key|
            page.page_fields.should have_key(key)
          end
          unwanted_keys = [
            :label_display,
            :sequence_number_display,
            :sequence_sort,
            :reference_image_url_s,
            :thumbnail_url_s,
            :viewer_url_s,
            :pdf_url_display,
            :parent_id_s,
            :coordinates_s,
          ]
          unwanted_keys.each do |key|
            page.page_fields.should_not have_key(key)
          end
          page.page_fields.should have_key(:unpaged_display)
          page.page_fields[:unpaged_display].should == true
        end
      end
    end

    context "Images in collections" do
      describe "#page_fields" do
        before (:each) do
          FileUtils.mkdir_p File.join(playground, 'mets')
          mets_src = File.join('data', 'dips', '77pa102', 'data', 'mets.xml')
          mets_file = File.join(playground, 'mets', 'mets2.xml')
          FileUtils.cp mets_src, mets_file
          @mets = KDL::METS.new
          @mets.load mets_file
        end

        after (:each) do
          FileUtils.rm_rf playground
        end

        it "includes publication date" do
          pd_dip_id = '77pa102'
          pd_page_id = 'FileGrp1'
          pd_dip_directory = File.join 'data', 'dips', pd_dip_id
          page = Page.new @mets, pd_page_id, pd_dip_id, pd_dip_directory, full_sample_solr_doc, false
          page.should have_finding_aid
          page.page_fields.should have_key(:pub_date)
          page.page_fields[:pub_date].should == '1864'
        end

        it "includes accession number" do
          pd_dip_id = '77pa102'
          pd_page_id = 'FileGrp1'
          pd_dip_directory = File.join 'data', 'dips', pd_dip_id
          page = Page.new @mets, pd_page_id, pd_dip_id, pd_dip_directory, full_sample_solr_doc, false
          page.should have_finding_aid
          page.page_fields.should have_key(:accession_number_s)
          # We were requested to keep a uniform accession number
          # for the entire collection.
          #page.page_fields[:accession_number_s].should == '77pa102_01'
          page.page_fields[:accession_number_s].should == '77pa102'
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

      describe "#browse_key_sort" do
        it "includes the first letter of the title, the sequence number, and the stopworded title" do
          page = Page.new mets, identifier, dip_id, dip_directory, {:title_processed_s => 'flow how not to be distracted by ooh shiny'}
          page.stub(:sequence_sort).and_return('00001')
          page.browse_key_sort.should == 'f00001 flow how not to be distracted by ooh shiny'
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

      describe "#thumbnail_url_s" do
        it "partially delegates to METS" do
          mets.stub(:thumbnail_path).and_return('66M37_1_01/0001/0001_tb.jpg')
          mets.should_receive(:thumbnail_path)
          page.thumbnail_url_s.should == "http://nyx.uky.edu/dips/#{dip_id}/data/66M37_1_01/0001/0001_tb.jpg"
        end
      end

      describe "#front_thumbnail_url_s" do
        it "partially delegates to METS" do
          mets.stub(:front_thumbnail_path).and_return('66M37_1_01/0001/0001_ftb.jpg')
          mets.should_receive(:front_thumbnail_path)
          page.front_thumbnail_url_s.should == "http://nyx.uky.edu/dips/#{dip_id}/data/66M37_1_01/0001/0001_ftb.jpg"
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

        it "uses the parent id for a finding aid" do
          page.stub(:finding_aid?).and_return(true)
          page.stub(:page_identifer).and_return('1_1_2_3')
          page.id.should == dip_id
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

      context "ALTO" do
        let(:alto_id) { 'sample_news_ndnp' }
        let(:alto_dip_directory) { File.join('data', 'dips', alto_id) }
        let(:page_id) { 'FileGrp0001' }

        before(:each) do
          @alto_mets = METS.new
          @alto_mets.load File.join(alto_dip_directory, 'data', 'mets.xml')
          @alto_page = Page.new @alto_mets, page_id, alto_id, alto_dip_directory, Hash.new
        end

        describe "#alto" do
          it "delegates to METS" do
            file = File.join(alto_dip_directory, 'data', '0000.xml')
            signatures_should_match(@alto_page.alto, Nokogiri::XML(IO.read(file)))
          end
        end
  
        describe "#coordinates_hash" do
          it "extracts a hash with words as keys and coordinates as values" do
            @alto_page.should_receive(:alto).and_return(sample_alto)
            got = @alto_page.coordinates_hash
            got.class.should == Hash
            expected = sample_coordinates_hash
            got.should == expected
          end
        end

        describe "#resolution" do
          it "partially delegates to METS" do
            @alto_page.resolution.should == 300
          end
        end
  
        describe "#coordinates_s" do
          it "dumps #coordinates_hash into JSON" do
            @alto_page.should_receive(:alto).and_return(sample_alto)
            got = @alto_page.coordinates_s
            expected = sample_coordinates_json
            JSON.parse(got).should == JSON.parse(expected)
          end
        end
      end
    end
  end
end

def sample_coordinates_json
  "{\"sample\":[[66.0,68.0,2292.0,466.0]],\"chowder\":[[32.0,33.0,1583.0,366.0]],\"howdy\":[[104.0,45.0,286.0,362.0],[74.0,70.0,1568.0,462.0]],\"this\":[[76.0,70.0,1766.0,462.0]],\"is\":[[70.0,74.0,1948.0,466.0]],\"alto\":[[68.0,72.0,2440.0,462.0]]}"
end

def sample_coordinates_hash
  {
    "sample" => [[66.0, 68.0, 2292.0, 466.0]], 
    "chowder" => [[32.0, 33.0, 1583.0, 366.0]], 
    "howdy" => [[104.0, 45.0, 286.0, 362.0], [74.0, 70.0, 1568.0, 462.0]], 
    "this" => [[76.0, 70.0, 1766.0, 462.0]], 
    "is" => [[70.0, 74.0, 1948.0, 466.0]], 
    "alto" => [[68.0, 72.0, 2440.0, 462.0]],
  }
end

def sample_alto
  text = <<-eos
  <Page ID="PAGE.0" HEIGHT="21036" WIDTH="12928" PHYSICAL_IMG_NR="1" PROCESSING="OCR.0" PC="0.956">
    <PrintSpace ID="PS.0" HEIGHT="21036.0" WIDTH="12928.0" HPOS="0.0" VPOS="0.0">
    <TextBlock xmlns:ns1="http://www.w3.org/1999/xlink" ID="TB.0001.1" HEIGHT="184" WIDTH="1040" HPOS="1144" VPOS="1444" ns1:type="simple" language="en">
      <TextLine ID="TB.0001.1_0" HEIGHT="184.0" WIDTH="1040.0" HPOS="1144.0" VPOS="1444.0">
        <String ID="TB.0001.1_0_0" STYLEREFS="TS_12.0" HEIGHT="180.0" WIDTH="416.0" HPOS="1144.0" VPOS="1448.0" CONTENT="howdy" WC="0.956"/>
        <SP WIDTH="92.0" HPOS="1560.0" VPOS="1444.0"/>
        <String ID="TB.0001.2_0_1" STYLEREFS="TS_11.0" HEIGHT="132.0" WIDTH="128.0" HPOS="6332.0" VPOS="1464.0" CONTENT="chowder" WC="0.956"/>
      </TextLine>

      <TextLine ID="TB.0001.2_3" HEIGHT="312.0" WIDTH="4928.0" HPOS="6272.0" VPOS="1848.0">
        <String ID="TB.0001.2_3_0" STYLEREFS="TS_10.0_B" HEIGHT="280.0" WIDTH="296.0" HPOS="6272.0" VPOS="1848.0" CONTENT="Howdy." WC="0.956"/>
        <SP WIDTH="496.0" HPOS="6568.0" VPOS="1848.0"/>
        <String ID="TB.0001.2_3_1" STYLEREFS="TS_10.0_BI" HEIGHT="280.0" WIDTH="304.0" HPOS="7064.0" VPOS="1848.0" CONTENT="This" WC="0.956"/>
        <SP WIDTH="424.0" HPOS="7368.0" VPOS="1848.0"/>
        <String ID="TB.0001.2_3_2" STYLEREFS="TS_10.0_BI" HEIGHT="296.0" WIDTH="280.0" HPOS="7792.0" VPOS="1864.0" CONTENT="is" WC="0.956"/>
        <SP WIDTH="1096.0" HPOS="8072.0" VPOS="1848.0"/>
        <String ID="TB.0001.2_3_3" STYLEREFS="TS_10.0_B" HEIGHT="272.0" WIDTH="264.0" HPOS="9168.0" VPOS="1864.0" CONTENT="sample" WC="0.956"/>
        <SP WIDTH="328.0" HPOS="9432.0" VPOS="1848.0"/>
        <String ID="TB.0001.2_3_4" STYLEREFS="TS_10.0_B" HEIGHT="288.0" WIDTH="272.0" HPOS="9760.0" VPOS="1848.0" CONTENT="ALTO" WC="0.956"/
      </TextLine>
    </TextBlock>
  </Page>
  eos
  Nokogiri::XML(text)
end

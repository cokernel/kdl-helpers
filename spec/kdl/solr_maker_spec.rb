require 'spec_helper'

module KDL
  describe SolrMaker do
    let(:output) { double('output').as_null_object }
    let(:access_package) { double('access_package').as_null_object }
    let(:playground) { File.join('data', 'playground') }
    let(:solrs_directory) { File.join(playground, 'solr') }
    let(:dip_id) { 'sample_aip' }
    let(:dip_id_oh) { 'sample_oral_history' }
    let(:solr_directory) { File.join(solrs_directory, dip_id) }
    let(:solr_directory_oh) { File.join(solrs_directory, dip_id_oh) }

    before(:each) do
      access_package.stub(:identifier).and_return(dip_id)
    end

    context "command-line interface" do
      describe "#help" do
        it "outputs a short usage note" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          output.should_receive(:puts)
          solr_maker.help
        end
      end
    end

    context "METS header fields" do
      describe "#repository_s" do
        it "delegates to AccessPackage" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          access_package.should_receive(:repository)
          solr_maker.repository_s
        end
      end

      describe "#date_digitized_display" do
        it "delegates to AccessPackage" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          access_package.should_receive(:date_digitized)
          solr_maker.date_digitized_display
        end
      end
    end

    context "Oral history fields" do
      context "when an oral history is present" do
        describe "#solr_doc" do
          it "includes synchronization_url_s" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasOralHistory).and_return(true)
            solr_maker.solr_doc.should have_key(:synchronization_url_s)
          end

          it "includes reference_audio_url_s" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasOralHistory).and_return(true)
            solr_maker.solr_doc.should have_key(:reference_audio_url_s)
          end

          it "includes text and text_s" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasOralHistory).and_return(true)
            solr_maker.solr_doc.should have_key(:text)
            solr_maker.solr_doc.should have_key(:text_s)
          end
        end

        describe "#sync_xml" do 
          it "delegates to AccessPackage" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasOralHistory).and_return(true)
            access_package.should_receive(:sync_xml)
            solr_maker.sync_xml
          end
        end

        describe "#oral_history_text" do
          it "pulls text from the synchronization XML file" do
            dip_directory_oh = File.join(
              'data',
              'dips',
              dip_id_oh
            )
            access_package_oh = AccessPackage.new dip_directory_oh
            access_package_oh.sync_xml.should_not be_nil
            solr_maker = SolrMaker.new output, access_package_oh, solrs_directory
            solr_maker.oral_history_text.should_not be_nil
            solr_maker.oral_history_text.should =~ /WARREN:\ Start/
          end
        end
      end
    end
    
    context "Finding aid fields" do
      describe "#solr_doc" do
        context "when a finding aid is present" do
          it "includes finding_aid_url_s" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasFindingAid).and_return(true)
            solr_maker.solr_doc.should have_key(:finding_aid_url_s)
          end

          it "sets :digital_content_available_s to true if digitized content is available" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasFindingAid).and_return(true)
            access_package.stub(:hasDigitizedContent).and_return(true)
            solr_maker.solr_doc.should have_key(:digital_content_available_s)
            solr_maker.solr_doc[:digital_content_available_s].should be_true
          end

          it "sets :digital_content_available_s to false if digitized content is not available" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasFindingAid).and_return(true)
            access_package.stub(:hasDigitizedContent).and_return(false)
            solr_maker.solr_doc.should have_key(:digital_content_available_s)
            solr_maker.solr_doc[:digital_content_available_s].should be_false
          end
        end

        context "when a finding aid is not present" do
          it "does not include finding_aid_url_s" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.stub(:hasFindingAid).and_return(false)
            solr_maker.solr_doc.should_not have_key(:finding_aid_url_s)
          end
        end
      end
    end

    context "Dublin Core fields" do
      context "fetching" do
        [
          :dc_contributor,
          :dc_coverage,
          :dc_creator,
          :dc_date,
          :dc_description,
          :dc_format,
          :dc_identifier,
          :dc_language,
          :dc_publisher,
          :dc_relation,
          :dc_rights,
          :dc_source,
          :dc_subject,
          :dc_title,
          :dc_type,
        ].each do |dc_field|
          it "delegates fetching <#{dc_field.to_s.sub(/_/, ':')}> to AccessPackage" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.should_receive(dc_field)
            solr_maker.send(dc_field)
          end
        end
      end

      context "KDL Solr fields with only one occurrence allowed" do
        [
          [:dc_title, :title_t],
          [:dc_title, :title_display],
          [:dc_title, :title_sort],
          [:dc_publisher, :publisher_t],
          [:dc_publisher, :publisher_display],
          [:dc_format, :format],
          [:dc_description, :description_t],
          [:dc_description, :description_display],
          [:dc_type, :type_display],
          [:dc_rights, :usage_display],
          [:dc_language, :language_display],
          [:dc_relation, :relation_display],
          [:dc_coverage, :coverage_s],
          [:dc_source, :source_s],
          [:dc_contributor, :contributor_s],
        ].each do |dc_field, solr_field|
          describe "##{solr_field}" do
            it "delegates fetching #{solr_field} to AccessPackage" do
              access_package.stub(dc_field).and_return(['sample', 'output'])
              solr_maker = SolrMaker.new output, access_package, solrs_directory
              solr_maker.send(solr_field).should == access_package.send(dc_field).first
            end
          end
        end

        describe "#title" do
          it "is a lowercased version of the title with initial stopwords removed" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            {
              'A, An, The: A Comparative History' => 'comparative history',
              'As the Code Churns' => 'code churns',
              'At the Whisky a Go Go' => 'whisky a go go',
              'Be the Change You Want to Become' => 'change you want to become',
              'But Me No Buts: A Guide to Yes' => 'me no buts a guide to yes',
              'By the Way, Your Nose is as Long as a Telephone Pole' => 'way your nose is as long as a telephone pole',
              'Do, or Do Not: There is No Try' => 'or do not there is no try',
              'For Score: Seven Years Playing Gammon on the Spanish Main' => 'score seven years playing gammon on the spanish main',
              'If: Rudyard Kipling and the Rise of Schlock' => 'rudyard kipling and the rise of schlock',
              'In the Flow: How Not to Be Distracted by Ooh Shiny' => 'flow how not to be distracted by ooh shiny',
              'Is it Me?' => 'me',
              'Of Things' => 'things',
              'On the Road Again' => 'road again',
              'The Quick Sly Fox' => 'quick sly fox',
              'To Boldly Split' => 'boldly split',
            }.each do |raw, processed|
              solr_maker.stub(:title_raw).and_return(raw)
              solr_maker.title.should == processed
            end
          end
        end

        describe "#author_t" do
          it "is a period-separated list of dc:creator elements" do
            dip_directory_oh = File.join([
              'data', 
              'dips',
              'sample_oral_history',
            ])
            access_package_oh = KDL::AccessPackage.new dip_directory_oh
            solr_maker_oh = KDL::SolrMaker.new output, access_package_oh, solrs_directory
            solr_maker_oh.author_t.should == 'Andrew Young; interviewee.  Robert Penn Warren; interviewer.'
          end
        end

        describe "#author_display" do
          it "is the same as #author_t" do
            dip_directory_oh = File.join([
              'data', 
              'dips',
              'sample_oral_history',
            ])
            access_package_oh = KDL::AccessPackage.new dip_directory_oh
            solr_maker_oh = KDL::SolrMaker.new output, access_package_oh, solrs_directory
            solr_maker_oh.author_display.should == solr_maker_oh.author_t
          end
        end

        describe "#pub_date" do
          it "partially delegates fetching pub_date to AccessPackage" do
            access_package.stub(:dc_date).and_return(['1908.02'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.pub_date.should == access_package.dc_date.first.gsub(/\D/, '')[0..3]
          end
        end

        describe "#full_date_s" do
          it "partially delegates fetching full_date_s to AccessPackage" do
            access_package.stub(:dc_date).and_return(['1900-01-02'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.full_date_s.should == access_package.dc_date.first
          end

          it "is empty if the date is not in YYYY-MM-DD format" do
            access_package.stub(:dc_date).and_return(['ca. 1900'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.full_date_s.should == ''
          end
        end
      end
  
      context "KDL Solr fields with multiple occurrences allowed" do
        describe "#subject_topic_facet" do
          it "delegates to AccessPackage" do
            access_package.stub(:dc_subject).and_return(['one', 'two', 'three'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.subject_topic_facet.should == access_package.dc_subject
          end
        end
      end
    end

    context "Export" do
      context "All objects" do
        describe "#solr_doc" do
          it "creates a hash of fields common to all pages" do
            access_package.stub(:dc_date).and_return(['1908.'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            [
              :author_t,
              :author_display,
              :title_t,
              :title_display,
              :title_sort,
              :title_processed_s,
              :description_t,
              :description_display,
              :subject_topic_facet,
              :pub_date,
              :full_date_s,
              :language_display,
              :usage_display,
              :publisher_t,
              :publisher_display,
              :repository_facet,
              :repository_display,
              :date_digitized_display,
              :format,
              :type_display,
              :relation_display,
              :mets_url_display,
              :coverage_s,
              :source_s,
              :contributor_s,
            ].each do |solr_field| 
              solr_maker.solr_doc.should have_key(solr_field)
            end
          end
        end
  
        describe "#pages" do
          it "delegates to AccessPackage" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            access_package.should_receive(:pages)
            solr_maker.pages
          end
        end
  
        describe "#mets_url_display" do
          it "returns the location of the METS file" do
            access_package.stub(:identifier).and_return('sample_aip')
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.mets_url_display.should == [
              'http://nyx.uky.edu/dips',
              access_package.identifier,
              'data/mets.xml',
            ].join('/')
          end
        end
      end

      context "Paged objects" do
        describe "#build" do
          it "passes save to each page" do
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.stub(:paged?).and_return(true)
            solr_maker.stub(:pages).and_return([double('page').as_null_object])
            solr_maker.pages.each do |page|
              page.should_receive(:save).with(solr_directory)
            end
            solr_maker.build
          end
        end
      end

      context "Unpaged objects" do
        before(:each) do
          @dip_directory_oh = File.join([
            'data', 
            'dips',
            'sample_oral_history',
          ])
          @access_package_oh = KDL::AccessPackage.new @dip_directory_oh
          @solr_maker_oh = KDL::SolrMaker.new output, @access_package_oh, solrs_directory
        end

        after(:each) do
        end

        describe "#solr_doc" do
          it "sets the id field" do
            @solr_maker_oh.solr_doc.should have_key(:id)
            @solr_maker_oh.solr_doc[:id].should == @solr_maker_oh.identifier
          end

          it "sets the unpaged field" do
            @solr_maker_oh.solr_doc.should have_key(:unpaged_display)
            @solr_maker_oh.solr_doc[:unpaged_display].should == '1'
          end
        end

        describe "#identifier" do
          it "delegates to AccessPackage" do
            access_package_oh = KDL::AccessPackage.new @dip_directory_oh
            solr_maker_oh = KDL::SolrMaker.new output, access_package_oh, solrs_directory
            solr_maker_oh.identifier.should == access_package_oh.identifier
          end
        end

        describe "#build" do
          it "calls save" do
            @solr_maker_oh.should_receive(:save)
            @solr_maker_oh.build
          end
        end

        describe "#save" do
          it "serializes solr_doc to a JSON file in the Solr directory set during initialization" do
            @solr_maker_oh.save 
            File.file?(File.join(solr_directory_oh, @solr_maker_oh.identifier)).should be_true
          end
        end
      end
    end
  end
end

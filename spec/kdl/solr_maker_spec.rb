require 'spec_helper'

module KDL
  describe SolrMaker do
    let(:output) { double('output').as_null_object }
    let(:access_package) { double('access_package').as_null_object }
    let(:playground) { File.join('data', 'playground') }
    let(:solrs_directory) { File.join(playground, 'solr') }
    let(:dip_id) { 'sample_aip' }
    let(:solr_directory) { File.join(solrs_directory, dip_id) }

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
    
    context "Finding aid fields" do
      describe "#solr_doc" do
        it "includes finding_aid_url_s when a finding aid is present" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          access_package.stub(:hasFindingAid).and_return(true)
          solr_maker.solr_doc.should have_key(:finding_aid_url_s)
        end

        it "does not include finding_aid_url_s when a finding aid is not present" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          access_package.stub(:hasFindingAid).and_return(false)
          solr_maker.solr_doc.should_not have_key(:finding_aid_url_s)
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
          [:dc_creator, :author_t],
          [:dc_creator, :author_display],
          [:dc_publisher, :publisher_t],
          [:dc_publisher, :publisher_display],
          [:dc_format, :format],
          [:dc_description, :description_t],
          [:dc_description, :description_display],
          [:dc_type, :type_display],
          [:dc_rights, :usage_display],
          [:dc_language, :language_display],
          [:dc_relation, :relation_display],
        ].each do |dc_field, solr_field|
          describe "##{solr_field}" do
            it "delegates fetching #{solr_field} to AccessPackage" do
              access_package.stub(dc_field).and_return(['sample', 'output'])
              solr_maker = SolrMaker.new output, access_package, solrs_directory
              solr_maker.send(solr_field).should == access_package.send(dc_field).first
            end
          end
        end

        describe "#pub_date" do
          it "partially delegates fetching pub_date to AcessPackage" do
            access_package.stub(:dc_date).and_return(['1908.02'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.pub_date.should == access_package.dc_date.first.gsub(/\D/, '')[0..3]
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
      describe "#build" do
        it "passes save to each page" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          solr_maker.stub(:pages).and_return([double('page').as_null_object])
          solr_maker.pages.each do |page|
            page.should_receive(:save).with(solr_directory)
          end
          solr_maker.build
        end
      end

      describe "#solr_doc" do
        it "creates a hash of fields common to all pages" do
          access_package.stub(:dc_date).and_return('1908.')
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          [
            :author_t,
            :author_display,
            :title_t,
            :title_display,
            :title_sort,
            :description_t,
            :description_display,
            :subject_topic_facet,
            :pub_date,
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
  end
end

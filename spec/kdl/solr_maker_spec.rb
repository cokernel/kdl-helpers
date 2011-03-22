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

    context "METS header fields" do
      describe "#repository" do
        it "delegates to AccessPackage" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          access_package.should_receive(:repository)
          solr_maker.repository
        end
      end

      describe "#date_digitized" do
        it "delegates to AccessPackage" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          access_package.should_receive(:date_digitized)
          solr_maker.date_digitized
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
          [:dc_title, :title],
          [:dc_creator, :author],
          [:dc_publisher, :publisher],
          [:dc_format, :format],
          [:dc_description, :description],
          [:dc_type, :type],
          [:dc_rights, :usage],
          [:dc_language, :language],
          [:dc_date, :date],
        ].each do |dc_field, solr_field|
          describe "##{solr_field}" do
            it "delegates fetching #{solr_field} to AccessPackage" do
              access_package.stub(dc_field).and_return(['sample', 'output'])
              solr_maker = SolrMaker.new output, access_package, solrs_directory
              solr_maker.send(solr_field).should == access_package.send(dc_field).first
            end
          end
        end
      end
  
      context "KDL Solr fields with multiple occurrences allowed" do
        describe "#subjects" do
          it "delegates to AccessPackage" do
            access_package.stub(:dc_subject).and_return(['one', 'two', 'three'])
            solr_maker = SolrMaker.new output, access_package, solrs_directory
            solr_maker.subjects.should == access_package.dc_subject
          end
        end
      end
    end

    context "Index-specific fields" do
      describe "#parent_id" do
        it "delegates to AccessPackage" do
          access_package.stub(:dc_identifier).and_return(['sample_identifier'])
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          solr_maker.parent_id.should == 'sample_identifier'
        end
      end
    end

    context "Export" do
      describe "#save" do
        it "passes save to each page" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          solr_maker.stub(:pages).and_return([double('page').as_null_object])
          solr_maker.pages.each do |page|
            page.should_receive(:save).with(solr_directory)
          end
          solr_maker.save
        end
      end

      describe "#solr_doc" do
        it "creates a hash of fields common to all pages" do
          solr_maker = SolrMaker.new output, access_package, solrs_directory
          [
            :author,
            :title,
            :description,
            :subjects,
            :date,
            :language,
            :usage,
            :publisher,
            :parent_id,
            :repository,
            :format,
            :type,
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
    end
  end
end

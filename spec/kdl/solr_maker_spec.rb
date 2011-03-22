require 'spec_helper'

module KDL
  describe SolrMaker do
    let(:output) { double('output').as_null_object }
    let(:dips_directory) { File.join('data', 'dips') }
    let(:dip_id) { 'sample_aip' }
    let(:dip_directory) { File.join(dips_directory, dip_id) }

    before(:each) do
      @access_package = AccessPackage.new dip_directory
      @mets = Nokogiri::XML(open(File.join(dip_directory, 'data', 'mets.xml')))
      @dublin_core = Nokogiri::XML(@mets.xpath('//oai_dc:dc').first.to_s)
      @solr_maker = SolrMaker.new output, @access_package
    end

    context "METS header fields" do
      describe "#repository" do
        it "delegates to AccessPackage" do
          access_package = double('access_package')
          solr_maker = SolrMaker.new output, access_package
          access_package.should_receive(:repository)
          solr_maker.repository
        end
      end
    end

    context "Dublin Core fields" do
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
        ].each do |dc_field, solr_field|
          describe "##{solr_field}" do
            it "returns the value of the first <dc:#{dc_field.to_s.sub(/^dc_/, '')}> element from input" do
              @solr_maker.send(solr_field).should == @dublin_core.xpath("//dc:#{dc_field.to_s.sub(/^dc_/, '')}").collect { |n| n.content }.first
            end
          end
        end
      end
  
      context "KDL Solr fields with multiple occurrences allowed" do
        describe "#subjects" do
          it "returns a list of <dc:subject> values" do
            @solr_maker.subjects.should == @dublin_core.xpath("//dc:subject").collect { |n| n.content }
          end
        end
      end
    end

    context "Index-specific fields" do
      describe "#parent_id" do
        it "retrieves the identifier for the container object" do
          @solr_maker.parent_id.should == @dublin_core.xpath("//dc:identifier").collect { |n| n.content }.first
        end
      end
    end
  end
end

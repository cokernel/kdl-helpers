require 'spec_helper'

module KDL
  describe AccessPackage do
    let (:dips_directory) { File.join('data', 'dips') }
    let (:dip_id) { 'sample_aip' }
    let (:dip_directory) { File.join(dips_directory, dip_id) }
    let (:playground) { File.join('data', 'playground') }
    let (:mets_file) { File.join(dip_directory, 'data', 'mets.xml') }
    let (:mets_file_with_finding_aid) { File.join('data', 'mets', 'mets2.xml') }

    context "Dublin Core access" do
      [
        'dc_contributor',
        'dc_coverage',
        'dc_creator',
        'dc_date',
        'dc_description',
        'dc_format',
        'dc_identifier',
        'dc_language',
        'dc_publisher',
        'dc_relation',
        'dc_rights',
        'dc_source',
        'dc_subject',
        'dc_title',
        'dc_type',
      ].each do |dc_field|
        field = dc_field.sub(/dc_/, '')
        describe "#{dc_field}" do
          it "returns a list of all <dc:#{field}> elements from input" do
            access_package = AccessPackage.new(dip_directory)
            xml = Nokogiri::XML(open(mets_file))
            dublin_core = Nokogiri::XML(xml.xpath('//oai_dc:dc').first.to_s)
            expected = dublin_core.xpath("//dc:#{field}").collect { |n| n.content }
            access_package.send(dc_field).should == expected
          end
        end
      end
    end

    context "METS file access" do
      describe "#repository" do
        it "delegates to the METS object" do
          access_package = AccessPackage.new dip_directory
          access_package.mets.should_receive(:repository)
          access_package.repository
        end
      end

      describe "#date_digitized" do
        it "delegates to the METS object" do
          access_package = AccessPackage.new dip_directory
          access_package.mets.should_receive(:date_digitized)
          access_package.date_digitized
        end
      end

      describe "#ids" do
        it "delegates to the METS object" do
          access_package = AccessPackage.new dip_directory
          access_package.mets.should_receive(:ids)
          access_package.ids
        end
      end

      describe "#pages" do
        it "returns an array of Page objects" do
          access_package = AccessPackage.new dip_directory
          pages = access_package.pages Hash.new
          pages.each do |page|
            page.class.should == Page
          end
        end
      end
    end
    
    context "package information" do
      describe "#identifier" do
        it "returns the package identifier for the DIP" do
          access_package = AccessPackage.new dip_directory
          access_package.identifier.should == File.basename(dip_directory)
        end
      end

      context "finding aid fields" do
        before(:each) do
          @dip_dir_with_finding_aid = File.join(playground, 'dip')
          FileUtils.mkdir_p File.join(@dip_dir_with_finding_aid, 'data')
          FileUtils.cp mets_file_with_finding_aid, File.join(@dip_dir_with_finding_aid, 'data', 'mets.xml')
        end

        after(:each) do
          FileUtils.rm_rf playground
        end
  
        describe "#hasFindingAid" do
          it "partially delegates to METS" do
            access_package = AccessPackage.new dip_directory
            access_package.mets.should_receive(:hasFileGrpWithUse).with('Finding Aid')
            access_package.hasFindingAid
          end
        end
  
        describe "#finding_aid_url" do
          it "partially delegates to METS" do
            access_package = AccessPackage.new @dip_dir_with_finding_aid
            access_package.mets.should_receive(:href).with(:fileGrp_use => 'Finding Aid', :file_use => 'access')
            access_package.finding_aid_url
          end
        end
      end
    end
  end
end

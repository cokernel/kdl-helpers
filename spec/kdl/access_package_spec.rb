require 'spec_helper'

module KDL
  describe AccessPackage do
    let (:dips_directory) { File.join('data', 'dips') }
    let (:dip_id) { 'sample_aip' }
    let (:dip_directory) { File.join(dips_directory, dip_id) }
    let (:playground) { File.join('data', 'playground') }
    let (:mets_file) { File.join(dip_directory, 'data', 'mets.xml') }
    let (:mets_file_with_finding_aid) { File.join('data', 'mets', 'mets2.xml') }
    let (:finding_aid_file) { File.join('data', 'mets', '66M37.dao.xml') }
    let (:mets_file_with_oral_history) { File.join('data', 'mets', 'mets3.xml') }

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

      context "oral history fields" do
        before(:each) do
          @dip_dir_with_oral_history = File.join(playground, 'dip')
          FileUtils.mkdir_p File.join(@dip_dir_with_oral_history, 'data')
          FileUtils.cp mets_file_with_oral_history, File.join(@dip_dir_with_oral_history, 'data', 'mets.xml')
          @access_package_oh = AccessPackage.new @dip_dir_with_oral_history
        end

        after(:each) do
          FileUtils.rm_rf playground
        end

        describe "#hasOralHistory" do
          it "partially delegates to METS" do
            @access_package_oh.mets.should_receive(:hasFileGrpWithUse).with('oral history')
            @access_package_oh.hasOralHistory
          end
        end

        describe "#sync_xml" do
          it "partially delegates to METS" do
            real_dip_dir = File.join(
              dips_directory,
              'sample_oral_history'
            )
            real_access_package_oh = KDL::AccessPackage.new real_dip_dir
            real_access_package_oh.hasOralHistory.should be_true
            real_access_package_oh.sync_xml
          end
        end

        describe "#synchronization_url" do
          it "partially delegates to METS" do
            @access_package_oh.hasOralHistory.should be_true
            @access_package_oh.synchronization_url
          end
        end

        describe "#reference_audio_url" do
          it "partially delegates to METS" do
            @access_package_oh.hasOralHistory.should be_true
            @access_package_oh.reference_audio_url
          end
        end
      end

      context "finding aid fields" do
        before(:each) do
          @dip_dir_with_finding_aid = File.join(playground, 'dip')
          FileUtils.mkdir_p File.join(@dip_dir_with_finding_aid, 'data')
          FileUtils.cp mets_file_with_finding_aid, File.join(@dip_dir_with_finding_aid, 'data', 'mets.xml')
          FileUtils.cp finding_aid_file, File.join(@dip_dir_with_finding_aid, 'data', '66M37.dao.xml')
        end

        after(:each) do
          FileUtils.rm_rf playground
        end

        describe "#pages" do
          it "includes a page for the finding aid" do
            access_package = AccessPackage.new @dip_dir_with_finding_aid
            pages = access_package.pages Hash.new
            pages.first.identifier.should == 'FileGrpFindingAid'
            pages.first.should be_finding_aid
          end

          it "does not mark other pages as finding aids" do
            access_package = AccessPackage.new @dip_dir_with_finding_aid
            pages = access_package.pages Hash.new
            pages.last.should_not be_finding_aid
          end
        end

        describe "#isFindingAid" do
          it "checks whether a specific item corresponds to a finding aid" do
            access_package = AccessPackage.new @dip_dir_with_finding_aid
            access_package.isFindingAid('FileGrpFindingAid').should be_true
            access_package.isFindingAid('FileGrp1_1_001_0001').should be_false
          end
        end
  
        describe "#hasFindingAid" do
          it "partially delegates to METS" do
            access_package = AccessPackage.new dip_directory
            access_package.mets.should_receive(:hasFileGrpWithUse).with('Finding Aid')
            access_package.hasFindingAid
          end
        end

        describe "#hasDigitizedContent" do
          it "partially delegates to METS" do
            access_package = AccessPackage.new dip_directory
            access_package.mets.should_receive(:ids)
            access_package.hasDigitizedContent
          end

          it "returns true if METS has at least 2 ids" do
            access_package = AccessPackage.new dip_directory
            access_package.mets.stub(:ids).and_return(['one', 'two'])
            access_package.hasDigitizedContent.should be_true
          end

          it "returns false if METS has less than 2 ids" do
            access_package = AccessPackage.new dip_directory
            access_package.mets.stub(:ids).and_return(['one'])
            access_package.hasDigitizedContent.should be_false
          end
        end
  
        describe "#finding_aid_url" do
          it "partially delegates to METS" do
            access_package = AccessPackage.new @dip_dir_with_finding_aid
            access_package.mets.should_receive(:href).with(:fileGrp_use => 'Finding Aid', :file_use => 'access')
            access_package.finding_aid_url
          end
        end

        describe "#finding_aid_text" do
          it "partially delegates to METS" do
            access_package = AccessPackage.new @dip_dir_with_finding_aid
            href = access_package.mets.href(:fileGrp_use => 'Finding Aid', :file_use => 'access')
            expected = Nokogiri::XML(IO.read(File.join(@dip_dir_with_finding_aid, 'data', href))).content
            expected.should_not be_nil
            access_package.finding_aid_text.should == expected
          end
        end
      end
    end
  end
end

require 'spec_helper'

module KDL
  describe METS do
    let (:fileGrp_id) { @mets.ids.first }
    let (:playground) { File.join('data', 'playground') }
    let (:aips_directory) { File.join('data', 'aips') }

    before(:each) do
      FileUtils::mkdir_p File.join(playground, 'mets')
      mets_src = File.join(aips_directory, 'sample_aip', 'data', 'mets.xml')
      @mets_file = File.join(playground, 'mets', 'mets.xml')
      FileUtils.cp mets_src, @mets_file
      @mets = KDL::METS.new
      @mets.load @mets_file
    end

    after(:each) do
      FileUtils::rm_rf playground
    end

    describe "#load" do
      it "loads a METS file into memory" do
        signatures_should_match @mets.mets,
          Nokogiri::XML(open(@mets_file))
      end
    end

    describe "#save" do
      it "makes a backup copy" do
        original = digest @mets_file 
        @mets.save
        File.exist?(@mets.backup_file).should be_true
        @mets.backup_file.should_not == @mets.mets_file
        saved = digest @mets.backup_file
        original.should == saved
      end

      it "does not change the METS file if nothing has changed" do
        original = digest @mets_file
        @mets.save
        saved = digest @mets_file
        original.should == saved
      end

      it "marks the file as unchanged" do
        @mets.save
        @mets.should_not be_changed
      end
    end

    describe "#ids" do
      it "fetches the list of fileGrp identifiers" do
        expected = @mets.mets.xpath('//mets:fileGrp').collect do |node|
          node['ID']
        end
        got = @mets.ids
        got.should == expected
      end
    end

    describe "#add_file" do
      before(:each) do 
        @mets.add_file :file => 'foo.js',
          :fileGrp => fileGrp_id,
          :use => 'script',
          :mimetype => 'text/javascript'
        @file = @mets.file :fileGrp => fileGrp_id,
                           :use => 'script'
        @file = @file.first
      end

      it "adds the right file to the correct fileGrp in the fileSec" do
        @file['ID'].should == 'ScriptFile0001'
        @file['USE'].should == 'script'
        @file['MIMETYPE'].should == 'text/javascript'

        @file.children.count.should == 1

        flocat = @file.children.first
        flocat.name.should == 'FLocat'
        flocat['xlink:href'].should == 'foo.js'
        flocat['LOCTYPE'].should == 'OTHER'
      end

      it "actually updates the METS file with the right file in the correct fileGrp" do
        href = @mets.href :fileGrp => fileGrp_id,
                         :use => 'script'
        href.should == 'foo.js'
      end

      it "adds a file to the correct div in the structMap" do
        master_id = @mets.file_id :fileGrp => fileGrp_id,
                                  :use => 'master' 
        the_div = @mets.div :master_id => master_id
        fptr = the_div.xpath("//mets:fptr[@FILEID='#{master_id}']")
        fptr.count.should == 1
      end

      it "marks the METS file as changed" do
        @mets.should be_changed
      end
    end

    describe "#remove_file" do
      it "removes a file from the correct fileGrp in the fileSec" do
        file_id = @mets.file_id :fileGrp => fileGrp_id,
                                :use => 'ocr'
        @mets.remove_file :file_id => file_id
        file = @mets.file :fileGrp => fileGrp_id,
                          :use => 'ocr'
        file.count.should == 0
      end

      it "removes a file from the correct div in the structMap" do
        file_id = @mets.file_id :fileGrp => fileGrp_id,
                                :use => 'ocr'
        @mets.remove_file :file_id => file_id
        fptr = @mets.mets.xpath("//mets:div/mets:fptr[@FILEID='#{file_id}']")
        fptr.count.should == 0
      end

      it "marks the METS file as changed" do
        file_id = @mets.file_id :fileGrp => fileGrp_id,
                                :use => 'ocr'
        @mets.remove_file :file_id => file_id
        @mets.should be_changed
      end
    end

    describe "#file" do
      it "returns the file for a given group and use" do
        expected_file = @mets.mets.xpath("//mets:fileGrp[@ID='#{fileGrp_id}']/mets:file[@USE='ocr']")
        got_file = @mets.file :fileGrp => fileGrp_id,
                              :use => 'ocr'
        got_file.should == expected_file
      end
    end

    describe "#href" do
      it "returns the file location for a given group and use" do
        expected_href = @mets.mets.xpath("//mets:fileGrp[@ID='#{fileGrp_id}']/mets:file[@USE='ocr']//mets:FLocat/@xlink:href").first.content
        got_href = @mets.href :fileGrp => fileGrp_id,
                              :use => 'ocr'
        got_href.should == expected_href
      end
    end

    describe "#file_id" do
      it "returns the file ID for a given group and use" do
        expected_file_id = @mets.mets.xpath("//mets:fileGrp[@ID='#{fileGrp_id}']/mets:file[@USE='ocr']/@ID").to_s
        got_file_id = @mets.file_id :fileGrp => fileGrp_id,
                                    :use => 'ocr'

        got_file_id.should == expected_file_id
      end
    end

    describe "#dublin_core" do
      it "retrieves the Dublin Core metadata from the document" do
        expected = Nokogiri::XML(@mets.mets.xpath("//oai_dc:dc").first.to_s)
        signatures_should_match(@mets.dublin_core, expected)
      end
    end
  end
end

def digest(file)
  Digest::MD5.hexdigest(File.read file)
end

def signatures_should_match(first, second)
  signature(first).should == signature(second)
end

def signature(xml)
  Lorax::Signature.new(xml.root).signature
end

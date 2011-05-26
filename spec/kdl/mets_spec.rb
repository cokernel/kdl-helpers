require 'spec_helper'

module KDL
  describe METS do
    let (:fileGrp_id) { @mets.ids.first }
    let (:fileGrp_id_tif) { 'FileGrp1_1_001_0001' }
    let (:playground) { File.join('data', 'playground') }
    let (:aips_directory) { File.join('data', 'aips') }
    let (:dips_directory) { File.join('data', 'dips') }

    before(:each) do
      FileUtils::mkdir_p File.join(playground, 'mets')
      mets_src = File.join(aips_directory, 'sample_aip', 'data', 'mets.xml')
      @mets_file = File.join(playground, 'mets', 'mets.xml')
      FileUtils.cp mets_src, @mets_file
      @mets = KDL::METS.new
      @mets.load @mets_file
      @mets2_src = File.join('data', 'mets', 'mets2.xml')
      @mets2_file = File.join(playground, 'mets', 'mets2.xml')
      FileUtils.cp @mets2_src, @mets2_file
      @mets_with_finding_aid = KDL::METS.new
      @mets_with_finding_aid.load @mets2_file
    end

    after(:each) do
      FileUtils::rm_rf playground
    end

    context "File operations" do
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
    end

    context "Package-level metadata" do
      describe "#ids" do
        it "fetches the list of fileGrp identifiers" do
          expected = @mets.mets.xpath('//mets:fileGrp').reject { |node| node['USE'] == 'Finding Aid' or node['USE'] == 'reel metadata' }.collect do |node|
            node['ID']
          end
          got = @mets.ids
          got.should == expected
        end
      end

      describe "#hasFileGrpWithUse" do
        it "essentially delegates to fileGrp" do
          @mets.hasFileGrpWithUse('Finding Aid').should be_false
          @mets_with_finding_aid.hasFileGrpWithUse('Finding Aid').should be_true
          @mets_with_finding_aid.hasFileGrpWithUse('Dessert topping').should be_false
        end
      end

      describe "#fileGrp" do
        it "returns the fileGrp for a given use" do
          @mets_with_finding_aid.fileGrp(:use => 'Finding Aid').should_not be_nil
          fileGrp = @mets_with_finding_aid.fileGrp(:use => 'Finding Aid').first
          fileGrp.xpath('mets:file[USE="access"]').should_not be_nil
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

        it "returns the file location for a given fileGrp use and file use" do
          expected_href = @mets_with_finding_aid.mets.xpath("//mets:fileGrp[@USE='Finding Aid']/mets:file[@USE='master']//mets:FLocat/@xlink:href").first.content
          got_href = @mets_with_finding_aid.href :fileGrp_use => 'Finding Aid',
            :file_use => 'master'
          got_href.should == expected_href
        end
      end

      describe "#mimetype" do
        it "returns the MIMETYPE for a given group and use" do
          expected_mime_type = 'image/tiff'
          got_mime_type = @mets_with_finding_aid.mimetype :fileGrp => fileGrp_id_tif,
                                         :use => 'master'
          got_mime_type.should == expected_mime_type
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
  
      describe "#repository" do
        it "returns the repository" do
          @mets.repository.should == @mets.mets.xpath('//mets:agent[@TYPE="REPOSITORY"]/mets:name').first.content
        end
      end
  
      describe "#date_digitized" do
        it "returns the date digitized" do
          @mets.date_digitized.should == @mets.mets.xpath('//mets:amdSec//mets:versionStatement').first.content
        end
      end
    end

    context "Modification" do
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
    end

    context "item-level metadata" do
      describe "#label_path" do
        it "returns the LABEL attributes of the mets:div for a given id and its eligible mets:div ancestors in descent order" do
          identifier = 'FileGrp1_1_002_0003'
          expected = [
            'I. Correspondence, 1839-1893',
            '1',
            'General to Anna Cooper, [11 February 1858]-11 September 1865',
            '3',
          ]
          @mets_with_finding_aid.label_path(identifier).should == expected
        end
      end

      describe "#order_path" do
        it "returns the ORDER attributes of the mets:div for a given id and its eligible mets:div ancestors in descent order" do
          identifier = 'FileGrp1_1_002_0003'
          expected = ['1', '1', '2', '3']
          @mets_with_finding_aid.order_path(identifier).should == expected
        end
      end

      describe "#sequence_number" do
        it "returns the sequence number for a given id" do
          identifier = @mets.ids.first
          div = @mets.div :fileGrp_id => identifier
          expected = div.first['ORDER']
          @mets.sequence_number(identifier).should == expected
        end
      end

      describe "#label" do
        it "returns the label for a given id" do
          identifier = @mets.ids.first
          div = @mets.div :fileGrp_id => identifier
          expected = div.first['LABEL']
          @mets.label(identifier).should == expected
        end
      end

      describe "#page_type" do
        it "returns the type for a given id" do
          identifier = @mets.ids.first
          div = @mets.div :fileGrp_id => identifier
          expected = div.first['TYPE']
          @mets.page_type(identifier).should == expected
        end
      end

      describe "#text_href" do
        it "returns the text location for a given id" do
          identifier = @mets.ids.first
          expected = @mets.href :fileGrp => identifier,
                                :use => 'ocr'
          @mets.text_href(identifier).should == expected
        end
      end

      describe "#alto_href" do
        it "returns the ALTO location for a given id" do
          mets = METS.new
          mets.load File.join('data', 'dips', 'sample_news_ndnp', 'data', 'mets.xml')
          identifier = mets.ids.first
          expected = mets.href :fileGrp => identifier,
                               :use => 'coordinates'
          mets.alto_href(identifier).should == expected
        end
      end

      describe "#reel_metadata_href" do
        it "returns the relative location of the reel metadata from NDNP reel metadata" do
          mets = METS.new
          mets.load File.join('data', 'dips', 'sample_news_ndnp', 'data', 'mets.xml')
          identifier = mets.ids.first
          mets.reel_metadata_href.should == '00017891803.xml'
        end
      end

      describe "#print_image_path" do
        it "returns the relative location for the print image for a given id" do
          dip_mets_src = File.join(dips_directory, 'sample_aip', 'data', 'mets.xml')
          dip_mets_file = File.join(playground, 'mets', 'dip-mets.xml')
          FileUtils.cp dip_mets_src, dip_mets_file
          mets = METS.new
          mets.load dip_mets_file
          identifier = mets.ids.first
          expected = mets.href :fileGrp => identifier,
                               :use => 'print image'
          expected.should_not be_nil
          mets.print_image_path(identifier).should == expected
        end
      end

      describe "#reference_image_path" do
        it "returns the relative location for the reference image for a given id" do
          dip_mets_src = File.join(dips_directory, 'sample_aip', 'data', 'mets.xml')
          dip_mets_file = File.join(playground, 'mets', 'dip-mets.xml')
          FileUtils.cp dip_mets_src, dip_mets_file
          mets = METS.new
          mets.load dip_mets_file
          identifier = mets.ids.first
          expected = mets.href :fileGrp => identifier,
                               :use => 'reference image'
          expected.should_not be_nil
          mets.reference_image_path(identifier).should == expected
        end
      end

      describe "#viewer_path" do
        it "returns the relative location for the gmapviewer metadata file for a given id" do
          dip_mets_src = File.join(dips_directory, 'sample_aip', 'data', 'mets.xml')
          dip_mets_file = File.join(playground, 'mets', 'dip-mets.xml')
          FileUtils.cp dip_mets_src, dip_mets_file
          mets = METS.new
          mets.load dip_mets_file
          identifier = mets.ids.first
          expected = mets.href :fileGrp => identifier,
                               :use => 'tiles metadata'
          expected.should_not be_nil
          mets.viewer_path(identifier).should == expected
        end
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

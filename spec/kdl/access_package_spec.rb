require 'spec_helper'

module KDL
  describe AccessPackage do
    let (:dips_directory) { File.join('data', 'dips') }
    let (:dip_id) { 'sample_aip' }
    let (:dip_directory) { File.join(dips_directory, dip_id) }
    let (:mets_file) { File.join(dip_directory, 'data', 'mets.xml') }

    describe "#title" do
      it "returns the value of the first <dc:title> element from input" do
        access_package = AccessPackage.new(dip_directory)
        xml = Nokogiri::XML(open(mets_file))
        dublin_core = Nokogiri::XML(xml.xpath('//oai_dc:dc').first.to_s)
        title = dublin_core.xpath('//dc:title').first.content
        access_package.title.should == title
      end
    end

    describe "#creator" do
      it "returns the value of the first <dc:creator> element from input" do
        access_package = AccessPackage.new(dip_directory)
        xml = Nokogiri::XML(open(mets_file))
        dublin_core = Nokogiri::XML(xml.xpath('//oai_dc:dc').first.to_s)
        creator = dublin_core.xpath('//dc:creator').first.content
        access_package.creator.should == creator
      end
    end
  end
end

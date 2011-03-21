require 'spec_helper'

module KDL
  describe SolrMaker do
    let(:output) { double('output').as_null_object }
    let(:access_package) { double('access_package').as_null_object }
    let(:dublin_core) { double('dublin_core') }

    context "METS header fields" do
      describe "repository" do
        it "returns the <access_package:name> of the repository" do
          access_package.stub(:repository).and_return(fake_sentence)
          solr_maker = SolrMaker.new output, access_package
          solr_maker.repository.should == access_package.repository
        end
      end
    end

    context "Dublin Core fields" do
      context "KDL Solr fields with only one occurrence allowed" do
        [
          [:title, :title],
          [:creator, :author],
          [:publisher, :publisher],
          [:format, :format],
          [:description, :description],
          [:type, :type],
          [:rights, :usage],
          [:language, :language],
        ].each do |dc_field, solr_field|
          describe "##{solr_field}" do
            it "returns the value of the first <dc:#{dc_field}> element from input" do
              dublin_core.stub(dc_field).and_return(fake_sentence)
              access_package.stub(:dublin_core).and_return(dublin_core)
              solr_maker = SolrMaker.new output, access_package
              solr_maker.send(solr_field).should == dublin_core.send(dc_field)
            end
          end
        end
      end
  
      context "KDL Solr fields with multiple occurrences allowed" do
        describe "#subjects" do
          it "returns a list of <dc:subject> values" do
            subjects = Array.new
            27.times do
              subjects << fake_sentence
            end
            dublin_core.stub(:subjects).and_return(subjects)
            access_package.stub(:dublin_core).and_return(dublin_core)
            solr_maker = SolrMaker.new output, access_package
            solr_maker.send(:subjects).should == dublin_core.send(:subjects)
          end
        end
      end
    end
  end
end

def fake_sentence
  words = []
  (1 + rand(10)).times do
    words << Array.new(1 + rand(7)) { 
      (rand(122-97) + 97).chr 
    }.join
  end
  words.join(' ')
end

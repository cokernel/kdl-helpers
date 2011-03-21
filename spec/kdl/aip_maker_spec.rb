require 'spec_helper'

module KDL
  describe AipMaker do
    let (:output) { double('output').as_null_object }
    let (:playground) { 'data/playground' }

    before(:each) do
      @sipbox = create_sample_sip
      @sip_directory = @sipbox.to_s
      @aip_id = "asking_for_deletion_#{rand(10000)}"
      @aips_directory = "#{playground}/aips"
    end

    after(:each) do
      @sipbox.cleanup!
      FileUtils::rm_rf(playground)
    end

    describe "#build" do
      before(:each) do
        @aipmaker = AipMaker.new output, @sip_directory, @aip_id, @aips_directory
        @aip = @aipmaker.build
      end
      
      after(:each) do
        @aipmaker.cleanup!
      end

      it "builds the AIP in the requested directory" do
        aips_directory = "#{playground}/fancy/aips"
        aipmaker = AipMaker.new output, @sip_directory, @aip_id, aips_directory
        aip = aipmaker.build
        aip.bag_dir.should == File.join(aips_directory, @aip_id)
        aipmaker.cleanup!
      end

      it "returns a valid Bag in the BagIt format" do
        @aip.class.should == BagIt::Bag
        @aip.should be_valid
      end

      it "returns a Bag whose data directory matches the contents of the SIP" do
        # AIP/data <= SIP
        seen = Hash.new
        @aip.bag_files.each do |file|
          if File.file? file
            path = Pathname.new(file).relative_path_from(Pathname.new(@aip.data_dir)).to_s
            File.exist?(File.join(@sip_directory, path)).should be_true
            seen[path.to_s] = 1
          end
        end
        # SIP <= AIP/data
        base_pathname = Pathname.new(@sip_directory)
        Find.find(@sip_directory) do |f|
          if File.file? f
            relative_path = Pathname.new(f).relative_path_from(base_pathname).to_s
            seen.should have_key relative_path
          end
        end
      end

      it "checks whether the checksums in the Bag match the contents of the SIP" do
        @aipmaker.cleanup!
        @aipmaker.should_receive(:check_fixity)
        @aipmaker.build
      end

      it "returns a Bag whose checksums match the contents of the SIP" do
        @aipmaker.should be_fixed_against_sip
      end

      it "outputs the location of the AIP on success" do
        @aipmaker.cleanup!
        output.should_receive(:puts).with("Built AIP at #{@aip.bag_dir}")
        @aipmaker.build
      end

      it "outputs the usage note when the directory for AIPs is omitted" do
        aipmaker = AipMaker.new output, @sip_directory, @aip_id
        aipmaker.should_receive(:usage)
        aipmaker.build
      end

      it "outputs the usage note when the identifier is omitted" do
        aipmaker = AipMaker.new output, @sip_directory
        aipmaker.should_receive(:usage)
        aipmaker.build
      end

      it "outputs the usage note when the SIP location is omitted" do
        aipmaker = AipMaker.new output
        aipmaker.should_receive(:usage)
        aipmaker.build
      end

    end

    describe "#check_fixity" do
      it "checks internal fixity of the AIP and compares with the SIP" do
        aipmaker = AipMaker.new output, @sip_directory, @aip_id, @aips_directory
        aip = aipmaker.build
        aipmaker.should_receive(:fixed_against_sip?)
        aip.should_receive(:fixed?)
        aipmaker.check_fixity
        aipmaker.cleanup!
      end

      it "outputs an error when SIP and AIP diverge" do
        aipmaker = AipMaker.new output, @sip_directory, @aip_id, @aips_directory
        aip = aipmaker.build
        trash_directory(@sip_directory)
        output.should_receive(:puts).with("Fixity error: SIP at #{@sip_directory} and AIP at #{aip.bag_dir} have different checksums")
        aipmaker.check_fixity
        aipmaker.cleanup!
      end

      it "outputs an error when AIP fails fixity check" do
        aipmaker = AipMaker.new output, @sip_directory, @aip_id, @aips_directory
        aip = aipmaker.build
        trash_directory(aip.data_dir)
        output.should_receive(:puts).with("Fixity error: AIP at #{aip.bag_dir} failed fixity check")
        aipmaker.check_fixity
        aipmaker.cleanup!
      end
    end

    describe "#usage" do
      it "outputs a short usage note" do
        aipmaker = AipMaker.new output
        # not testing content of note here
        output.should_receive(:puts)
        aipmaker.usage
      end
    end

    describe "#cleanup!" do
      it "clears out the AIP directory" do
        aipmaker = AipMaker.new output, @sip_directory, @aip_id, @aips_directory
        aip = aipmaker.build
        aipmaker.cleanup!
        File.exist?(aip.bag_dir).should_not be_true
      end
    end
  end
end

def trash_directory(directory)
  Find.find(directory) do |f|
    if File.file? f 
      File.open(f, 'w') do |io|
        io.write 'MOAR DATA CORRUPTION PLZ'
      end
    end
  end
end

def create_sample_sip
  sandbox = Sandbox.new
  # create a few sample files
  10.times do |n|
    File.open(File.join(sandbox.to_s, "file_#{n}"), 'w') do |io|
      io.write 'howdy'
    end
    path = [ sandbox.to_s ]
    (1..n).each do |i|
      path << "dir_#{n}_#{i}"
      FileUtils.mkdir(File.join(path))
      File.open(File.join(path, "file_#{n}_#{i}"), 'w') do |io|
       io.write 'chowder'
      end
    end
  end
  File.open(File.join(sandbox.to_s, 'mets.xml'), 'w') do |io|
    io.write '<mets/>'
  end
  sandbox
end

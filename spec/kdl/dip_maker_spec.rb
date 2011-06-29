require 'spec_helper'

module KDL
  describe DipMaker do
    let (:output) { double('output').as_null_object }
    let (:playground) { 'data/playground' }
    let (:aip_directory) { 'data/aips/sample_aip' }
    let (:aip_directory_oh) { 'data/aips/sample_oral_history' }
    let (:dips_directory) { "#{playground}/dips" }
    let (:dipmaker) { DipMaker.new output, aip_directory, dips_directory }
    let (:dipmaker_oh) { DipMaker.new output, aip_directory_oh, dips_directory }
    let (:dipmaker_mets_only) { DipMaker.new output, aip_directory, dips_directory, :mets_only => true}
    let (:dipmaker_with_own_id) { DipMaker.new output, aip_directory, dips_directory, :dip_directory => 'test_id' }

    after(:each) do
      FileUtils.rm_rf(dips_directory)
    end

    describe "#stage" do
      it "sets @dip_directory to the directory name of the AIP directory if no other name is provided" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        File.basename(dipmaker.dip_directory).should == File.basename(aip_directory)
      end

      it "accepts a DIP id provided in the options" do
        dipmaker_with_own_id.stage
        File.basename(dipmaker_with_own_id.dip_directory).should == 'test_id'
      end


      it "copies the AIP to the DIPs directory" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        # we eventually want a Pairtree
        File.directory?(dip_directory).should be_true
        aip = BagIt::Bag.new aip_directory
        dip = BagIt::Bag.new dip_directory
        # DIP/data <= AIP/data
        dip.bag_files.each do |file|
          path = Pathname.new(file).relative_path_from(Pathname.new(dip.data_dir)).to_s
          File.exist?(File.join(aip.data_dir, path)).should be_true
        end
        # AIP/data <= DIP/data
        aip.bag_files.each do |file|
          path = Pathname.new(file).relative_path_from(Pathname.new(aip.data_dir)).to_s
          File.exist?(File.join(dip.data_dir, path)).should be_true
        end
      end

      it "opens the METS file in place" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        dipmaker.mets.class.should == KDL::METS
        dipmaker.mets.should be_loaded
      end
    end

    describe "#generate_tiles" do
      it "does not attempt to tile non-TIFF files" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory_oh))
        dipmaker_oh.stage
        tiler = Tiler.new output
        tiler.should_not_receive(:run)
        dipmaker_oh.generate_tiles(tiler)
      end

      it "create tiles files and removes master files if the METS file is loaded" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        tiler = Tiler.new output
        dipmaker.generate_tiles(tiler)
        dip = BagIt::Bag.new dip_directory
        dipmaker.mets.ids.each do |fileGrp_id|
          href = dipmaker.mets.href :fileGrp => fileGrp_id,
                            :use => 'thumbnail'
          href.length.should be > 0
          File.file?(File.join(dip_directory, 'data', href)).should be_true
          href = dipmaker.mets.href :fileGrp => fileGrp_id,
                            :use => 'tiled image'
          href.length.should be > 0
          File.file?(File.join(dip_directory, 'data', href)).should be_true
          href = dipmaker.mets.href :fileGrp => fileGrp_id,
                            :use => 'tiles metadata'
          href.length.should be > 0
          File.file?(File.join(dip_directory, 'data', href)).should be_true
          href = dipmaker.mets.href :fileGrp => fileGrp_id,
                            :use => 'reference image'
          href.length.should be > 0
          File.file?(File.join(dip_directory, 'data', href)).should be_true
          href = dipmaker.mets.href :fileGrp => fileGrp_id,
                            :use => 'print image'
          href.length.should be > 0
          File.file?(File.join(dip_directory, 'data', href)).should be_true
        end
      end

      it "removes tiff images from the METS file" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker_mets_only.stage
        tiler = Tiler.new output
        dipmaker_mets_only.generate_tiles(tiler)
        dip = BagIt::Bag.new dip_directory
        dipmaker_mets_only.mets.ids.each do |fileGrp_id|
          tiff_href = dipmaker_mets_only.mets.href :fileGrp => fileGrp_id,
                            :use => 'tiff image'
          master_href = dipmaker_mets_only.mets.href :fileGrp => fileGrp_id,
                            :use => 'master'
          if master_href.length > 0
            tiff_href.length.should == 0
          end
        end
      end

      it "updates the METS file with tile files (removing master representations) if the METS file is loaded" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        tiler = double('tiler').as_null_object
        dipmaker.generate_tiles(tiler)
        dipmaker.mets.ids.each do |fileGrp_id|
          dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'thumbnail').
                                length.should be > 0
          dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'front thumbnail').
                                length.should be > 0
          dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'tiled image').
                                length.should be > 0
          dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'tiles metadata').
                                length.should be > 0
          dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'reference image').
                                length.should be > 0
          dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'print image').
                                length.should be > 0
        end
      end

      it "updates removing tiff image representations if the METS file is loaded" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        tiler = double('tiler').as_null_object
        dipmaker.generate_tiles(tiler)
        dipmaker.mets.ids.each do |fileGrp_id|
          master_length = dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                :use => 'master').length
          if master_length > 0
            dipmaker.mets.file_id(:fileGrp => fileGrp_id,
                                  :use => 'tiff image').
                                  length.should == 0
          end
        end
      end

      it "outputs an error message if the METS file is not loaded" do
        output.should_receive(:puts).with("No METS file loaded.")
        dipmaker.generate_tiles
      end

      it "outputs an error message if no tiler object is provided" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        dipmaker.stage
        output.should_receive(:puts).with("No tiler provided.")
        dipmaker.generate_tiles
      end
    end

    describe "#build" do
      it "stages construction of the DIP" do
        dipmaker.should_receive(:stage)
        dipmaker.build
      end

      it "produces tiles for each master file" do
        dipmaker.should_receive(:generate_tiles)
        dipmaker.build
      end

      it "outputs the location of the DIP on success" do
        dip_directory = File.join(dips_directory, File.basename(aip_directory))
        output.should_receive(:puts).with("Built DIP at #{dip_directory}")
        dipmaker_mets_only.build
      end

      it "outputs the usage note when the AIP directory is omitted" do
        dipmaker = DipMaker.new output
        dipmaker.should_receive(:usage)
        dipmaker.build
      end

      it "outputs the usage note when the DIPs directory is omitted" do
        dipmaker = DipMaker.new output, aip_directory
        dipmaker.should_receive(:usage)
        dipmaker.build
      end

      it "skips the usage note when all arguments are provided" do
        dipmaker_mets_only.should_not_receive(:usage)
        dipmaker_mets_only.build
      end
    end

    describe "#usage" do
      it "outputs a short usage note" do
        output.should_receive(:puts)
        dipmaker.usage
      end
    end
  end
end

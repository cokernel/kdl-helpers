require 'spec_helper'

module KDL
  describe Tiler do
    let (:output) { double('output').as_null_object }

    describe "#command" do
      it "sets the --input-directory option" do
        tiler = Tiler.new output
        tiler.configure :input_directory => '/path/to/input'
        tiler.command.should include('--input-directory=/path/to/input')
      end

      it "sets the --output-directory option" do
        tiler = Tiler.new output
        tiler.configure :output_directory => '/path/to/output'
        tiler.command.should include('--output-directory=/path/to/output')
      end

      it "sets the --no-move option" do
        tiler = Tiler.new output
        tiler.configure :no_move => true
        tiler.command.should include('--no-move')
      end

      it "sets the --delete option" do
        tiler = Tiler.new output
        tiler.configure :delete => true
        tiler.command.should include('--delete')
      end

      it "sets the --quiet option" do
        tiler = Tiler.new output
        tiler.configure :quiet => true
        tiler.command.should include('--quiet')
      end

      it "allows the --file option" do
        tiler = Tiler.new output
        tiler.configure :file => '/path/to/file'
        tiler.command.should include('--file=/path/to/file')
      end

      it "produces an entire command string" do
        tiler = Tiler.new output
        tiler.configure :input_directory => '/path/to/input',
                  :output_directory => '/path/to/output',
                  :no_move => true,
                  :quiet => true,
                  :file => 'just/this/one'
        tiler.command.should == '/opt/pdp/bin/tiler.py --input-directory=/path/to/input --output-directory=/path/to/output --no-move --quiet --file=just/this/one'
      end
    end

    describe "#run" do
      before(:each) do
        @input_directory = 'data/aips/sample_aip/data'
        @output_directory = 'data/tiler_test'
        @file = '0001.tif'
        @base = '0001'
        @metadata_file = '0001.txt'
        @tile_file = '0001.tls'
        @thumb_file = '0001_tb.jpg'
        FileUtils.mkdir_p(@output_directory)
      end

      after(:each) do
        FileUtils.rm_rf(@output_directory)
      end

      context "when no explicit initialization is peformed" do
        before(:each) do 
          @tiler = Tiler.new output
        end

        it "sends an error message to output" do
          output.should_receive(:puts).with("The tiler must be initialized before it can be used.")
          @tiler.run
        end

        it "does not actually run the external tiler program" do
          files = [
            @metadata_file,
            @tile_file,
            @thumb_file,
          ]
          files.each do |file|
            path = File.join(@output_directory,
                             @base,
                             file)
            File.exist?(path).should_not be_true
          end
          @tiler.run
          files.each do |file|
            path = File.join(@output_directory,
                             @base,
                             file)
            File.exist?(path).should_not be_true
          end
        end
      end

      context "when full initialization is performed" do
        before(:each) do
          @tiler = Tiler.new output
          @tiler.configure :input_directory => @input_directory,
                    :output_directory => @output_directory,
                    :no_move => true,
                    :quiet => true,
                    :file => @file
        end

        it "actually runs the external tiler program" do
          files = [
            @metadata_file,
            @tile_file,
            @thumb_file,
          ]
          files.each do |file|
            path = File.join(@output_directory,
                             @base,
                             file)
            File.exist?(path).should_not be_true
          end
          @tiler.run
          files.each do |file|
            path = File.join(@output_directory,
                             @base,
                             file)
            File.exist?(path).should be_true
          end
        end

        it "does not send an error message to output" do
          output.should_not_receive(:puts)
          @tiler.run
        end
      end
    end
  end
end

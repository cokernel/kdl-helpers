#require 'spec/spec_helper'

module KDL
  class AipMaker
    def initialize(output, sip_directory=nil, identifier=nil, base_dir=nil)
      @output = output
      @sip_directory = sip_directory
      @identifier = identifier
      @base_dir = base_dir
    end

    def usage
      @output.puts "Usage: aipmaker <SIP directory> <identifier> <AIPs directory>"
    end
    
    def build
      if @base_dir.nil? or @sip_directory.nil? or @identifier.nil?
        return usage
      end
      FileUtils::mkdir_p(@base_dir)
      @bag = BagIt::Bag.new(File.join(@base_dir, @identifier))
      sip_pathname = Pathname.new(@sip_directory)
      if File.directory? @sip_directory
        Find.find(@sip_directory) do |sipfile|
          if File.file? sipfile
            path = Pathname.new(sipfile).relative_path_from(sip_pathname).to_s
            @bag.add_file(path, sipfile)
          end
        end
      end
      @bag.manifest!
      if check_fixity
        @output.puts("Built AIP at #{@bag.bag_dir}")
      end
      @bag
    end

    def check_fixity
      good = true
      unless fixed_against_sip?
        @output.puts("Fixity error: SIP at #{@sip_directory} and AIP at #{@bag.bag_dir} have different checksums")
        good = false
      end
      unless @bag.fixed?
        @output.puts("Fixity error: AIP at #{@bag.bag_dir} failed fixity check")
        good = false
      end
      good
    end

    def fixed_against_sip?
      # modified from lib/bagit/manifest.rb#fixed?
      @bag.manifest_files.all? do |mf|
        # extract the algorithm
        mf =~ /manifest-(.+).txt$/

        algo = case $1
               when /sha1/i
                 Digest::SHA1
               when /md5/i
                 Digest::MD5
               else
                 :unknown
               end

        # check it, an unknown algorithm is always true
        unless algo == :unknown
          lines = open(mf) { |io| io.readlines }

          lines.all? do |line|
            manifested_digest, path = line.chomp.split /\s+/, 2
            path = Pathname.new(path).relative_path_from(Pathname.new('data')).to_s
            actual_digest = open(File.join(@sip_directory, path)) { |io| algo.hexdigest io.read }
            actual_digest == manifested_digest
          end
        else
          true
        end
      end
    end

    def cleanup!
      FileUtils.rm_rf(@bag.bag_dir)
    end
  end
end

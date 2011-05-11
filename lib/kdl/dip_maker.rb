require 'spec/spec_helper'

module KDL
  class DipMaker
    attr_reader :aip_directory, :dips_directory, :mets

    def initialize(output, aip_directory=nil, dips_directory=nil, options = Hash.new)
      @output = output
      @aip_directory = aip_directory
      @dips_directory = dips_directory
      @mets = METS.new
      @options = options
    end

    def build
      if @aip_directory.nil? or @dips_directory.nil?
        return usage
      end
      stage
      generate_tiles(Tiler.new @output)
      @output.puts("Built DIP at #{@dip_directory}")
    end

    def generate_tiles(tiler=nil)
      if @mets.loaded? and tiler
        @mets.ids.each do |fileGrp_id|
          use = 'tiff image'
          href = @mets.href :fileGrp => fileGrp_id,
                            :use => use
          if href.length == 0
            use = 'master'
            href = @mets.href :fileGrp => fileGrp_id,
                              :use => use
          end

          mimetype = @mets.mimetype :fileGrp => fileGrp_id,
                                    :use => use

          return unless mimetype == "image/tiff"

          stem = File.basename(href, '.tif')
          base = File.join(
            File.dirname(href),
            stem
          )
          tiler.configure :input_directory => @dip.data_dir,
                         :output_directory => @dip.data_dir,
                         :no_move => true,
                         :delete => true,
                         :quiet => true,
                         :file => href

          thumb_href = File.join(base, stem + '_tb.jpg')
          tls_href = File.join(base, stem + '.tls')
          meta_href = File.join(base, stem + '.txt')
          ref_href = File.join(base, stem + '.jpg')
          pdf_href = File.join(base, stem + '.pdf')

          if @options.has_key?(:mets_only)
            # fake creation
            FileUtils.mkdir_p File.join(@dip.data_dir, base)
            [
              thumb_href,
              tls_href,
              meta_href,
              ref_href,
              pdf_href,
            ].each do |file|
              FileUtils.touch File.join(@dip.data_dir, file)
            end
          else
            tiler.run
          end

          @mets.add_file :fileGrp => fileGrp_id,
                         :use => 'thumbnail',
                         :file => thumb_href,
                         :mimetype => 'image/jpeg'

          @mets.add_file :fileGrp => fileGrp_id,
                         :use => 'tiled image',
                         :file => tls_href,
                         :mimetype => 'application/octet-stream'

          @mets.add_file :fileGrp => fileGrp_id,
                         :use => 'tiles metadata',
                         :file => meta_href,
                         :mimetype => 'text/plain'

          @mets.add_file :fileGrp => fileGrp_id,
                         :use => 'reference image',
                         :file => ref_href,
                         :mimetype => 'image/jpeg'

          @mets.add_file :fileGrp => fileGrp_id,
                         :use => 'print image',
                         :file => pdf_href,
                         :mimetype => 'application/pdf'

          master_id = @mets.file_id :fileGrp => fileGrp_id,
                         :use => use
          @mets.remove_file :file_id => master_id
          @mets.save
          @dip.manifest!
        end
        @mets.save
      else
        @output.puts "No METS file loaded."
      end
      if tiler.nil?
        @output.puts "No tiler provided."
      end
    end

    def stage
      @aip = BagIt::Bag.new @aip_directory
      @dip_directory = File.join(@dips_directory, File.basename(@aip_directory))
      FileUtils.mkdir_p @dips_directory unless File.directory? @dips_directory
      @dip = BagIt::Bag.new @dip_directory
      Find.find(@aip.data_dir) do |aipfile|
        if File.file? aipfile
          path = Pathname.new(aipfile).relative_path_from(Pathname.new(@aip.data_dir)).to_s
          @dip.add_file(path, aipfile)
        end
      end
      @dip.manifest!
      @mets.load(File.join(@dip.data_dir, 'mets.xml'))
    end

    def usage
      @output.puts "Usage: dipmaker <AIP directory> <DIPs directory>"
    end
  end
end

require 'kdl/mets'
require 'kdl/tiler'
require 'exifr'
require 'mustache'

module KDL
  class DipMaker
    attr_reader :aip_directory, :dips_directory, :mets
    attr_reader :dip_directory

    def initialize(output, aip_directory=nil, dips_directory=nil, options = Hash.new)
      @output = output
      @aip_directory = aip_directory
      @dips_directory = dips_directory
      @mets = METS.new
      @options = options
      begin
        if @options.has_key?(:dip_directory) and @options[:dip_directory].length > 0
          @basename = @options[:dip_directory]
        else
          @basename = File.basename(@aip_directory)
        end
      rescue
        @basename = ''
      end
      if @dips_directory
        @dip_directory = File.join(@dips_directory, @basename) 
      end
    end

    def build
      if @aip_directory.nil? or @dips_directory.nil?
        return usage
      end
      stage
      update_reel_metadata
      generate_tiles(Tiler.new @output)
      @output.puts("Built DIP at #{@dip_directory}")
      cleanup
    end

    def update_reel_metadata
      if @mets.reel_metadata_href
        reel_metadata_file = File.join @dip_directory, 'data', @mets.reel_metadata_href
        tiff_file = File.join @dip_directory,
                              'data',
                              @mets.href(:fileGrp => @mets.ids.first, :use => 'master')
        dpi = EXIFR::TIFF.new(tiff_file).x_resolution.to_i
        xml = Nokogiri::XML open(reel_metadata_file)
        xml.xpath('//ndnp:captureResolutionOriginal').first.content = dpi
        File.open(reel_metadata_file, 'w') { |f| xml.write_xml_to f }
        @dip.manifest!
      end
    end

    def cleanup
      pn = Pathname.new(File.join @dip_directory, 'data')
      Find.find(File.join @dip_directory, 'data') do |path|
        if File.file?(path)
          rpn = Pathname.new(path)
          relpath = rpn.relative_path_from(pn)
          if relpath
            unless @mets.referenced?(relpath.to_s) or relpath.to_s == 'mets.xml'
              @output.puts %-Deleting unreferenced file #{relpath}-
              @dip.remove_file(relpath)
            end
          end
        end
      end
      @dip.manifest!
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

          case mimetype
          when "image/tiff"
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
            
            pdf_path = @mets.print_image_path(fileGrp_id)
            if pdf_path.nil? or pdf_path.length == 0
              pdf_path = @mets.href :fileGrp => fileGrp_id,
                                    :use => 'master'
              if pdf_path.nil? or pdf_path.length == 0
                wants_pdf = true
              else
                if pdf_path =~ /\.pdf$/
                  wants_pdf = false
                else
                  wants_pdf = true
                end
              end
            else
              wants_pdf = false
            end
  
            thumb_href = File.join(base, stem + '_tb.jpg')
            front_thumb_href = File.join(base, stem + '_ftb.jpg')
            tls_href = File.join(base, stem + '.tls')
            meta_href = File.join(base, stem + '.txt')
            ref_href = File.join(base, stem + '.jpg')
  
            if wants_pdf
              pdf_href = File.join(base, stem + '.pdf')
            else
              tiler.configure :make_pdfs => false
            end
  
            if @options.has_key?(:mets_only)
              # fake creation
              FileUtils.mkdir_p File.join(@dip.data_dir, base)
              [
                thumb_href,
                front_thumb_href,
                tls_href,
                meta_href,
                ref_href,
              ].each do |file|
                FileUtils.touch File.join(@dip.data_dir, file)
              end
              if wants_pdf
                FileUtils.touch File.join(@dip.data_dir, pdf_href)
              end
            else
              tiler.run
            end
  
            @mets.add_file :fileGrp => fileGrp_id,
                           :use => 'thumbnail',
                           :file => thumb_href,
                           :mimetype => 'image/jpeg'
  
            @mets.add_file :fileGrp => fileGrp_id,
                           :use => 'front thumbnail',
                           :file => front_thumb_href,
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
  
            if wants_pdf
              @mets.add_file :fileGrp => fileGrp_id,
                             :use => 'print image',
                             :file => pdf_href,
                             :mimetype => 'application/pdf'
            end
  
            master_id = @mets.file_id :fileGrp => fileGrp_id,
                           :use => use
            @mets.remove_file :file_id => master_id
          when /^(vnd.)?audio\/(x-)?wave?$/
            # We assume that the OGG and MP3 files have already been generated,
            # so we can just remove the master audio.
            stem = File.basename(href, '.wav')
            base = File.join(
              File.dirname(href),
              stem
            )
            master_id = @mets.file_id :fileGrp => fileGrp_id,
                           :use => use
            @mets.remove_file :file_id => master_id
          end
        end
        @mets.save
        @dip.manifest!
      else
        @output.puts "No METS file loaded."
      end
      if tiler.nil?
        @output.puts "No tiler provided."
      end
    end

    def stage
      @aip = BagIt::Bag.new @aip_directory
      FileUtils.mkdir_p @dips_directory unless File.directory? @dips_directory
      @dip = BagIt::Bag.new @dip_directory
      Find.find(@aip.data_dir) do |aipfile|
        if File.file? aipfile
          unless aipfile =~ /\.dao\.xml/
            path = Pathname.new(aipfile).relative_path_from(Pathname.new(@aip.data_dir)).to_s
            @dip.add_file(path, aipfile)
          else
            path = Pathname.new(aipfile).relative_path_from(Pathname.new(@aip.data_dir)).to_s
            dipfile = Mustache.render(IO.read(aipfile), :dip_id => @basename)
            @dip.add_file(path) { |io|
              io.puts dipfile
            }
          end
        end
      end
      @dip.manifest!
      @mets.load(File.join(@dip.data_dir, 'mets.xml'))
    end

    def usage
      @output.puts "Usage: dipmaker <AIP directory> <DIPs directory> [DIP identifier]"
    end
  end
end

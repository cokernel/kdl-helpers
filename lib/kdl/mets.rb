require 'spec/spec_helper'

module KDL
  class METS
    attr_reader :mets
    attr_reader :mets_file
    attr_reader :backup_file

    def initialize
      @loaded = false
    end

    def load(mets_file)
      @mets_file = mets_file
      @mets = Nokogiri::XML open(@mets_file)
      @mets_changed = false
      @loaded = true
    end

    def loaded?
      @loaded
    end

    def save
      backup
      return unless @mets_changed
      File.open(@mets_file, 'w') do |f|
        @mets.write_xml_to f
      end
      @mets_changed = false
    end

    def dublin_core
      Nokogiri::XML(@mets.xpath('//oai_dc:dc').first.to_s)
    end

    def repository
      query = '//mets:agent[@TYPE="REPOSITORY"]/mets:name'
      @mets.xpath(query).first.content
    end

    def date_digitized
      query = '//mets:amdSec//mets:versionStatement'
      @mets.xpath(query).first.content
    end

    def backup
      @backup_file = [
        @mets_file,
        '.bak',
      ].join('')
      FileUtils.cp @mets_file, @backup_file
    end

    def add_file(options)
      id = file_id :fileGrp => options[:fileGrp],
                       :use => options[:use]
      if id.length > 0
        #return file :fileGrp => options[:fileGrp],
        #            :use => options[:use]
      else
        flocat = Nokogiri::XML::Node.new "FLocat", @mets
        flocat['xlink:href'] = options[:file]
        flocat['LOCTYPE'] = 'OTHER'
  
        the_file = Nokogiri::XML::Node.new "file", @mets
        file_id = file_id_for options[:use], options[:fileGrp]
        the_file['ID'] = file_id
        the_file['USE'] = options[:use]
        the_file['MIMETYPE'] = options[:mimetype]
  
        the_file.add_child(flocat)
  
        @mets.xpath("//mets:fileGrp[@ID='#{options[:fileGrp]}']").first.add_child(the_file)
  
        fptr = Nokogiri::XML::Node.new "fptr", @mets
        fptr['FILEID'] = file_id
  
        master_id = file_id_for 'master', options[:fileGrp]

        the_div = div :master_id => master_id
        the_div.first.add_child(fptr)
  
        @mets_changed = true
        #file
      end
      file :fileGrp => options[:fileGrp],
           :use => options[:use]
    end

    def remove_file(options)
      @mets.xpath("//mets:file[@ID='#{options[:file_id]}']").first.remove
      @mets.xpath("//mets:div/mets:fptr[@FILEID='#{options[:file_id]}']").first.remove
      @mets_changed = true
    end

    def changed?
      @mets_changed
    end

    def ids
      mets.xpath('//mets:fileGrp').collect do |node|
        node['ID']
      end
    end

    def file_id_for(use, group_id)
      use.gsub(/\s+/, '_').camelize + group_id.sub('FileGrp', 'File')
    end

    def div(options)
      if options.has_key?(:master_id)
        query = "//mets:div[mets:fptr[@FILEID='#{options[:master_id]}']]"
      elsif options.has_key?(:fileGrp_id)
        id = file(:fileGrp => options[:fileGrp_id]).first['ID']
        query = "//mets:div[mets:fptr[@FILEID='#{id}']]"
      end
      @mets.xpath(query)
    end

    def file(options)
      if options.has_key?(:use)
        query = "//mets:fileGrp[@ID='#{options[:fileGrp]}']/mets:file[@USE='#{options[:use]}']"
      else
        query = "//mets:fileGrp[@ID='#{options[:fileGrp]}']/mets:file"
      end
      @mets.xpath(query)
    end

    def href(options)
      query = "//mets:fileGrp[@ID='#{options[:fileGrp]}']/mets:file[@USE='#{options[:use]}']//mets:FLocat"
      result = @mets.xpath(query).first
      if result.nil?
        ''
      elsif result['xlink:href'].nil?
        result['href']
      else
        result['xlink:href']
      end
    end

    def file_id(options)
      query = "//mets:fileGrp[@ID='#{options[:fileGrp]}']/mets:file[@USE='#{options[:use]}']/@ID"
      @mets.xpath(query).to_s
    end

    def print_image_path(identifier)
      href :fileGrp => identifier,
           :use => 'print image'
    end

    def reference_image_path(identifier)
      href :fileGrp => identifier,
           :use => 'reference image'
    end

    def viewer_path(identifier)
      href :fileGrp => identifier,
           :use => 'tiles metadata'
    end

    def sequence_number(identifier)
      div(:fileGrp_id => identifier).first['ORDER']
    end

    def label(identifier)
      div(:fileGrp_id => identifier).first['LABEL']
    end

    def page_type(identifier)
      div(:fileGrp_id => identifier).first['TYPE']
    end

    def text_href(identifier)
      href :fileGrp => identifier, 
           :use => 'ocr'
    end
  end
end

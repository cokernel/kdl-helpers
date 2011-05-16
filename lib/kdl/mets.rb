require 'spec/spec_helper'

module KDL
  class METS
    attr_reader :mets
    attr_reader :mets_file
    attr_reader :backup_file
    attr_reader :ineligible_types

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
      Nokogiri::XML(@mets.xpath('//oai_dc:dc', @mets.collect_namespaces).first.to_s)
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
      if id.length == 0
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
      mets.xpath('//mets:fileGrp').reject { |node| node['USE'] == 'Finding Aid' }.collect do |node|
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

    def hasFileGrpWithUse(use)
      fileGrp(:use => use).length > 0
    end

    def fileGrp(options)
      query = "//mets:fileGrp[@USE='#{options[:use]}']"
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
      if options.has_key?(:fileGrp_use)
        query = "//mets:fileGrp[@USE='#{options[:fileGrp_use]}']/mets:file[@USE='#{options[:file_use]}']//mets:FLocat"
      else
        query = "//mets:fileGrp[@ID='#{options[:fileGrp]}']/mets:file[@USE='#{options[:use]}']//mets:FLocat"
      end
      result = @mets.xpath(query).first
      if result.nil?
        ''
      elsif result['xlink:href'].nil?
        result['href'].gsub(/^\.\//, '')
      else
        result['xlink:href'].gsub(/^\.\//, '')
      end
    end

    def self.add_file_attr(method_name, attribute)
      define_method method_name do |options|
        query = "//mets:fileGrp[@ID='#{options[:fileGrp]}']/mets:file[@USE='#{options[:use]}']/@#{attribute}"
        @mets.xpath(query).to_s
      end
    end

    add_file_attr :mimetype, :MIMETYPE
    add_file_attr :file_id, :ID

    def label_path(identifier)
      the_div = div(:fileGrp_id => identifier).first
      the_path = [the_div['LABEL']]
      while the_div.parent.name == 'div'
        the_path.unshift the_div.parent['LABEL']
        the_div = the_div.parent
      end
      the_path
    end

    def order_path(identifier)
      the_div = div(:fileGrp_id => identifier).first
      the_path = [the_div['ORDER']]
      while the_div.parent.name == 'div'
        the_path.unshift the_div.parent['ORDER']
        the_div = the_div.parent
      end
      the_path
    end

    def self.add_href_field(method_name, use)
      define_method method_name do |identifier|
        href :fileGrp => identifier,
             :use => use.to_s.gsub(/_/, ' ')
      end
    end

    add_href_field :print_image_path, :print_image
    add_href_field :reference_image_path, :reference_image
    add_href_field :viewer_path, :tiles_metadata
    add_href_field :text_href, :ocr

    def self.add_div_field(method_name, field)
      define_method method_name do |identifier|
        div(:fileGrp_id => identifier).first[field.to_s]
      end
    end

    add_div_field :sequence_number, :ORDER
    add_div_field :label, :LABEL
    add_div_field :page_type, :TYPE
  end
end

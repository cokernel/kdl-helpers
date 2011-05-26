require 'spec/spec_helper'

module KDL
  class METS
    attr_reader :mets
    attr_reader :mets_file
    attr_reader :backup_file

    def initialize
      @loaded = false
    end

    def loaded?
      @loaded
    end

    def changed?
      @changed
    end

    def mark_changed
      @changed = true
    end

    # raw file access

    def load(mets_file)
      @mets_file = mets_file
      @mets = Nokogiri::XML open(@mets_file)
      @changed = false
      @loaded = true
    end

    def save
      backup
      return unless @changed
      File.open(@mets_file, 'w') do |f|
        @mets.write_xml_to f
      end
      @changed = false
    end

    def backup
      @backup_file = [
        @mets_file,
        '.bak',
      ].join('')
      FileUtils.cp @mets_file, @backup_file
    end

    # object-level metadata

    def dublin_core
      Nokogiri::XML(@mets.xpath('//oai_dc:dc', @mets.collect_namespaces).first.to_s)
    end

    def self.add_canned_query(method_name, query)
      define_method method_name do
        @mets.xpath(query).first.content
      end
    end

    add_canned_query :repository, '//mets:agent[@TYPE="REPOSITORY"]/mets:name'
    add_canned_query :date_digitized, '//mets:amdSec//mets:versionStatement'

    # item-level metadata

    def ids
      mets.xpath('//mets:fileGrp').reject { |node| node['USE'] == 'Finding Aid' or node['USE'] == 'reel metadata' }.collect do |node|
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

    def self.add_path(method_name, field)
      define_method method_name do |identifier|
        the_div = div(:fileGrp_id => identifier).first
        the_path = [the_div[field.to_s]]
        while the_div.parent.name == 'div'
          the_path.unshift the_div.parent[field.to_s]
          the_div = the_div.parent
        end
        the_path
      end
    end

    add_path :label_path, :LABEL
    add_path :order_path, :ORDER

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
    add_href_field :alto_href, :coordinates

    def reel_metadata_href
      node = mets.xpath('//mets:fileGrp').select { |node| node['USE'] == 'reel metadata' }.first
      href :fileGrp => node['ID'],
           :use => 'reel metadata'
    end

    def self.add_div_field(method_name, field)
      define_method method_name do |identifier|
        div(:fileGrp_id => identifier).first[field.to_s]
      end
    end

    add_div_field :sequence_number, :ORDER
    add_div_field :label, :LABEL
    add_div_field :page_type, :TYPE

    # file modification

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
  
        @changed = true
      end
      file :fileGrp => options[:fileGrp],
           :use => options[:use]
    end

    def remove_file(options)
      @mets.xpath("//mets:file[@ID='#{options[:file_id]}']").first.remove
      @mets.xpath("//mets:div/mets:fptr[@FILEID='#{options[:file_id]}']").first.remove
      @changed = true
    end
  end
end

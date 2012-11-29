require 'spec/spec_helper'

module KDL
  class AccessPackage
    attr_reader :mets

    def initialize(dip_directory)
      @dip_directory = dip_directory
      @mets_file = File.join(dip_directory, 'data', 'mets.xml')
      @mets = METS.new
      @mets.load @mets_file
    end

    def identifier
      File.basename(@dip_directory)
    end

    def pages(solr_doc)
      @mets.ids.collect do |id|
        doc = solr_doc.dup
        if isFindingAid(id)
          doc[:text] = finding_aid_text
        elsif solr_doc.has_key?(:finding_aid_url_s)
          doc.delete(:description_t)
          doc.delete(:description_display)
          doc.delete(:pub_date)
          doc.delete(:subject_topic_facet)
        end
        Page.new @mets, id, identifier, @dip_directory, doc, isFindingAid(id)
      end
    end

    def sync_xml
      if hasOralHistory
        item = @mets.href :fileGrp_use => 'oral history',
                          :file_use => 'synchronization'

        unless item.nil?
          file = File.join @dip_directory, 'data', item
          xml = Nokogiri::XML(open(file))
        end
      end
    end

    def synchronization_url
      oral_history_url 'synchronization' 
    end

    def reference_audio_url
      oral_history_url 'reference audio'
    end

    def oral_history_url(use)
      if hasOralHistory
        item = @mets.href :fileGrp_use => 'oral history',
                          :file_use => use

        unless item.nil?
          item.sub!( /\.xml$/, '')
          "http://nyx.uky.edu/oh/render.php?cachefile=#{item}"
        end
      end
    end

    def finding_aid_url
      if hasFindingAid
        [ 'http://nyx.uky.edu/dips',
          identifier,
          'data',
          @mets.href(:fileGrp_use => 'Finding Aid',
                     :file_use => 'access')
        ].join('/')
      end
    end

    def finding_aid_xml
      if @finding_aid_xml.nil?
        @finding_aid_xml = Nokogiri::XML(
          IO.read(
            File.join(
              @dip_directory,
              'data',
              @mets.href(:fileGrp_use => 'Finding Aid',
                         :file_use => 'access'))))
      end
      @finding_aid_xml
    end

    def finding_aid_text
      if hasFindingAid
        finding_aid_xml.content
      else
        return ''
      end
    end

    def hasOralHistory
      @mets.hasFileGrpWithUse('oral history')
    end

    def isFindingAid(id)
      if hasFindingAid
        fileGrp = @mets.fileGrp(:use => 'Finding Aid').first
        fileGrp['ID'] == id
      else
        false
      end
    end

    def hasFindingAid
      @mets.hasFileGrpWithUse('Finding Aid')
    end

    def hasDigitizedContent
      begin
        ids.count > 1
      rescue
        false
      end
    end

    def ids
      @mets.ids
    end

    def repository
      @mets.repository
    end

    def date_digitized
      if hasFindingAid
        begin
          xml = finding_aid_xml
          xml.xpath('//xmlns:date[@type="dao"]').first.content
        rescue
          @mets.date_digitized
        end
      else
        @mets.date_digitized
      end
    end

    def method_missing(name, *args)
      dc_field = name.to_s
      if dc_field =~ /^dc_/
        query = "//dc:#{dc_field.sub(/^dc_/, '')}"
        @mets.dublin_core.xpath(query).collect { |n| n.content }
      else
        super
      end
    end
  end
end

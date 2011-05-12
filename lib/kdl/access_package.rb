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
        Page.new @mets, id, identifier, @dip_directory, solr_doc
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

    def hasOralHistory
      @mets.hasFileGrpWithUse('oral history')
    end

    def hasFindingAid
      @mets.hasFileGrpWithUse('Finding Aid')
    end

    def ids
      @mets.ids
    end

    def repository
      @mets.repository
    end

    def date_digitized
      @mets.date_digitized
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

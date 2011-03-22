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

    def pages
      @mets.ids.collect do |id|
        Page.new @mets, id
      end
    end

    def ids
      @mets.ids
    end

    def repository
      @mets.repository
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

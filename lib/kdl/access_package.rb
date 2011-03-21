require 'spec/spec_helper'

module KDL
  class AccessPackage
    def initialize(dip_directory)
      @dip_directory = dip_directory
      @mets_file = File.join(dip_directory, 'data', 'mets.xml')
      @mets = METS.new
      @mets.load @mets_file
    end

    def method_missing(name, *args)
      dc_field = name.to_s
      if dc_field =~ /^dc_/
        query = "//dc:#{dc_field.sub(/^dc_/, '')}"
        @mets.dublin_core.xpath(query).collect { |n| n.content }
      end
    end

    def repository
      query = '//mets:agent[@TYPE="REPOSITORY"]/mets:name'
      @mets.mets.xpath(query).first.content
    end
  end
end

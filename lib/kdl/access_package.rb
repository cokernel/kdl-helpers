require 'spec/spec_helper'

module KDL
  class AccessPackage
    def initialize(dip_directory)
      @dip_directory = dip_directory
      @mets_file = File.join(dip_directory, 'data', 'mets.xml')
      @mets = METS.new
      @mets.load @mets_file
    end

    def title
      @mets.dublin_core.xpath('//dc:title').first.content
    end
  end
end

require 'spec/spec_helper'

module KDL
  class SolrMaker
    def initialize(output, mets)
      @mets = mets
      @dublin_core = @mets.dublin_core
    end

    def self.dublin_core_export(dc_field, solr_field=nil)
      method_name = solr_field ? solr_field : dc_field
      define_method(method_name) {
        @dublin_core.send(dc_field)
      }
    end

    def self.mets_export(mets_field, solr_field=nil)
      method_name = solr_field ? solr_field : mets_field
      define_method(method_name) {
        @mets.send(mets_field)
      }
    end

    dublin_core_export :title
    dublin_core_export :publisher
    dublin_core_export :format
    dublin_core_export :description
    dublin_core_export :type
    dublin_core_export :language
    dublin_core_export :subjects
    dublin_core_export :creator, :author
    dublin_core_export :rights, :usage
    mets_export        :repository
  end
end

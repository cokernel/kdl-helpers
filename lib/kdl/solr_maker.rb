require 'spec/spec_helper'

module KDL
  class SolrMaker
    def initialize(output, access_package)
      @access_package = access_package
    end

    def self.dublin_core_export(dc_field, solr_field=nil, count=1)
      method_name = solr_field ? solr_field : dc_field
      if count == 1
        define_method(method_name) {
          @access_package.send(dc_field).first
        }
      else
        define_method(method_name) {
          @access_package.send(dc_field)
        }
      end
    end

    def repository 
      @access_package.repository
    end

    def id
      @access_package.dc_identifier.first
    end

    dublin_core_export :dc_title, :title
    dublin_core_export :dc_publisher, :publisher
    dublin_core_export :dc_format, :format
    dublin_core_export :dc_description, :description
    dublin_core_export :dc_type, :type
    dublin_core_export :dc_language, :language
    dublin_core_export :dc_creator, :author
    dublin_core_export :dc_rights, :usage
    dublin_core_export :dc_subjects, :subjects, '*'
  end
end

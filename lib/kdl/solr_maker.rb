require 'spec/spec_helper'

module KDL
  class SolrMaker
    def initialize(output, access_package, solrs_directory)
      @output = output
      @access_package = access_package
      @solrs_directory = solrs_directory
      @solr_directory = File.join(@solrs_directory, @access_package.identifier)
    end

    def help
      @output.puts "Usage: solrmaker <DIP directory> <SOLR exports directory>"
    end

    def save
      pages.each do |page|
        page.save @solr_directory
      end
    end

    def solr_doc
      hash = {}
      [
        :author,
        :title,
        :description,
        :subjects,
        :date,
        :language,
        :usage,
        :publisher,
        :parent_id,
        :repository,
        :format,
        :type,
      ].each do |solr_field|
        hash[solr_field] = send(solr_field)
      end
      hash
    end

    def repository 
      @access_package.repository
    end

    def date_digitized
      @access_package.date_digitized
    end

    def parent_id
      @access_package.dc_identifier.first
    end

    def subjects
      @access_package.dc_subject
    end

    def pages
      @access_package.pages solr_doc
    end

    def method_missing(name, *args)
      if name.to_s =~ /^dc_/
        @access_package.send(name)
      else
        super
      end
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

    dublin_core_export :dc_title, :title
    dublin_core_export :dc_publisher, :publisher
    dublin_core_export :dc_format, :format
    dublin_core_export :dc_description, :description
    dublin_core_export :dc_type, :type
    dublin_core_export :dc_language, :language
    dublin_core_export :dc_creator, :author
    dublin_core_export :dc_rights, :usage
    dublin_core_export :dc_date, :date
  end
end

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
        :author_t,
        :author_display,
        :title_t,
        :title_display,
        :description_t,
        :description_display,
        :subject_topic_facet,
        :date_facet,
        :language_facet,
        :usage_display,
        :publisher_t,
        :publisher_display,
        :parent_id_s,
        :repository_s,
        :date_digitized_display,
        :format_facet,
        :type_display,
      ].each do |solr_field|
        hash[solr_field] = send(solr_field)
      end
      hash
    end

    def repository_s
      @access_package.repository
    end

    def date_digitized_display
      @access_package.date_digitized
    end

    def parent_id_s
      @access_package.dc_identifier.first
    end

    def subject_topic_facet
      @access_package.dc_subject.flatten.uniq
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

    dublin_core_export :dc_title, :title_t
    dublin_core_export :dc_title, :title_display
    dublin_core_export :dc_publisher, :publisher_t
    dublin_core_export :dc_publisher, :publisher_display
    dublin_core_export :dc_format, :format_facet
    dublin_core_export :dc_description, :description_t
    dublin_core_export :dc_description, :description_display
    dublin_core_export :dc_type, :type_display
    dublin_core_export :dc_language, :language_facet
    dublin_core_export :dc_creator, :author_t
    dublin_core_export :dc_creator, :author_display
    dublin_core_export :dc_rights, :usage_display
    dublin_core_export :dc_date, :date_facet
  end
end

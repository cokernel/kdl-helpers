require 'spec/spec_helper'

module KDL
  class SolrMaker
    def initialize(output, access_package, solrs_directory)
      @output = output
      @access_package = access_package
      @solrs_directory = solrs_directory
      unless @access_package.nil?
        @solr_directory = File.join(@solrs_directory, @access_package.identifier)
      end
    end

    def help
      @output.puts "Usage: solrmaker <DIP directory> <SOLR exports directory>"
    end

    def build
      if paged?
        pages.each do |page|
          page.save @solr_directory
        end
      else
        save
      end
    end

    def save
      FileUtils.mkdir_p(@solr_directory)
      solr_file = File.join(@solr_directory, identifier)
      File.open(solr_file, 'w') { |f|
        hash = solr_doc.dup
        f.write hash.to_json
      }
    end

    def paged?
      not(@access_package.hasOralHistory)
    end

    def solr_doc
      hash = {}
      [
        :author_t,
        :author_display,
        :title_t,
        :title_display,
        :title_sort,
        :title_processed_s,
        :description_t,
        :description_display,
        :subject_topic_facet,
        :pub_date,
        :full_date_s,
        :language_display,
        :usage_display,
        :publisher_t,
        :publisher_display,
        :repository_facet,
        :repository_display,
        :date_digitized_display,
        :format,
        :type_display,
        :relation_display,
        :mets_url_display,
        :coverage_s,
        :source_s,
        :contributor_s,
      ].each do |solr_field|
        hash[solr_field] = send(solr_field)
      end
      if @access_package.hasOralHistory
        hash.merge! oral_history_fields
      end
      if @access_package.hasFindingAid
        hash.merge! finding_aid_fields
      end
      unless paged?
        hash[:id] = identifier
        hash[:unpaged_display] = '1'
      end
      hash[:object_id_s] = @access_package.identifier
      hash[:digital_content_available_s] = @access_package.hasDigitizedContent
      hash
    end

    def oral_history_fields
      hash = {}
      hash[:synchronization_url_s] = @access_package.synchronization_url
      hash[:reference_audio_url_s] = @access_package.reference_audio_url
      hash[:text] = oral_history_text
      hash[:text_s] = oral_history_text
      hash
    end

    def finding_aid_fields
      hash = {}
      hash[:finding_aid_url_s] = @access_package.finding_aid_url
      hash
    end

    def oral_history_text
      [
        sync_xml.xpath('//INST').first.content,
        sync_xml.xpath('//IDX').first.content,
      ].join(' ')
    end

    def sync_xml
      if @access_package.hasOralHistory
        @access_package.sync_xml
      end
    end

    def date_digitized_display
      @access_package.date_digitized
    end

    def subject_topic_facet
      @access_package.dc_subject.flatten.uniq
    end

    def pages
      @access_package.pages solr_doc
    end

    def mets_url_display
      [
        'http://nyx.uky.edu/dips',
        @access_package.identifier,
        'data/mets.xml',
      ].join('/')
    end

    def method_missing(name, *args)
      if name.to_s =~ /^dc_/
        @access_package.send(name)
      elsif name.to_s =~ /^repository/
        @access_package.repository
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

    def pub_date
      raw_date = @access_package.dc_date.first
      raw_date.gsub(/\D/, '')[0..3]
    end

    def full_date_s
      raw_date = @access_package.dc_date.first
      if raw_date =~ /^\d\d\d\d-\d\d-\d\d/
        raw_date[0..9]
      else
        ''
      end
    end

    def author_t
      @access_package.dc_creator.join('.  ') + '.'
    end

    def author_display
      author_t
    end

    def identifier
      @access_package.identifier
    end

    def stopwords
      [
        'a',
        'an',
        'as',
        'at',
        'be',
        'but',
        'by',
        'do',
        'for',
        'if',
        'in',
        'is',
        'it',
        'of',
        'on',
        'the',
        'to',
      ]
    end

    def title_processed_s
      title
    end

    def title
      words = title_raw.downcase.gsub(/[^a-z ]/, '').sub(/^insurance\ maps\ of\ /, '').split(/\s+/)
      while stopwords.include?(words.first)
        words.shift
      end
      words.join(' ')
    end

    dublin_core_export :dc_title, :title_raw
    dublin_core_export :dc_title, :title_t
    dublin_core_export :dc_title, :title_display
    dublin_core_export :dc_title, :title_sort
    dublin_core_export :dc_publisher, :publisher_t
    dublin_core_export :dc_publisher, :publisher_display
    dublin_core_export :dc_format, :format
    dublin_core_export :dc_description, :description_t
    dublin_core_export :dc_description, :description_display
    dublin_core_export :dc_type, :type_display
    dublin_core_export :dc_language, :language_display
    dublin_core_export :dc_rights, :usage_display
    dublin_core_export :dc_relation, :relation_display
    dublin_core_export :dc_coverage, :coverage_s
    dublin_core_export :dc_source, :source_s
    dublin_core_export :dc_contributor, :contributor_s
  end
end

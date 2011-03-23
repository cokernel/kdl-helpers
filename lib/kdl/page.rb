require 'spec/spec_helper'

module KDL
  class Page
    attr_reader :identifier
    attr_reader :solr_doc

    def initialize(mets, identifier, parent_id, dip_directory, solr_doc)
      @mets = mets
      @identifier = identifier
      @parent_id = parent_id
      @dip_directory = dip_directory
      @solr_doc = solr_doc
      @title = solr_doc[:title_display]
    end

    def save(solr_directory)
      FileUtils.mkdir_p(solr_directory)
      solr_file = File.join(solr_directory, id)
      File.open(solr_file, 'w') { |f|
        f.write page_fields.to_json
      }
    end

    def page_fields
      @solr_doc[:title_display] = "#{page_type.capitalize} #{label_display} of #{@title}"
      if sequence_number_display.to_i > 1
        new_solr_doc = Hash.new
        [
          :language_display,
          :usage_display,
          :format,
          :parent_id_s,
          :relation_display,
          :repository_display,
          :title_display,
          :title_sort,
        ].each do |solr_field|
          new_solr_doc[solr_field] = @solr_doc[solr_field]
        end
        the_title = "#{page_type.capitalize} #{label_display}"
        new_solr_doc[:title_t] = the_title
        #new_solr_doc[:title_display] = "#{the_title} of #{@title}"
        @solr_doc = new_solr_doc
      end
      [
        :id,
        :label_display,
        :sequence_number_display,
        :sequence_sort,
        :text,
      ].each do |page_field|
        @solr_doc[page_field] = send(page_field)
      end
      @solr_doc
    end

    def page_title
      if sequence_number_display.to_i > 1
        "#{type.capitalize} #{label_display}"
      else
        @solr_doc[:title_t]
      end
    end

    def id
      "#{@parent_id}_#{sequence_number_display}"
    end

    def sequence_number_display
      @mets.sequence_number @identifier
    end

    def sequence_sort
      sprintf("%05d", sequence_number_display)
    end

    def label_display
      @mets.label @identifier
    end

    def page_type
      @mets.page_type @identifier
    end

    def text
      begin
        IO.read(File.join(@dip_directory, 
                          'data', 
                          text_href))
      rescue
        ''
      end
    end

    def text_href
      @mets.text_href @identifier
    end
  end
end

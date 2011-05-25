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
      the_label = 
      if page_type == 'sequence'
        sequence_number_display
      else
        label_display
      end
      label_path = @mets.label_path @identifier
      label_path.pop
      label_path.push "#{page_type.capitalize} #{the_label}"
      @solr_doc[:title_display] = "#{label_path.join(' > ')} of #{@title}"
      @solr_doc[:title_guide_display] = @solr_doc[:title_sort]
      @solr_doc[:title_t] = @solr_doc[:title_display]
      [
        :id,
        :label_display,
        :sequence_number_display,
        :sequence_sort,
        :text,
        :text_s,
        :reference_image_url_s,
        :viewer_url_s,
        :pdf_url_display,
        :parent_id_s,
      ].each do |page_field|
        @solr_doc[page_field] = send(page_field)
      end
      unless @solr_doc[:source_s].nil?
        @solr_doc[:text] += @solr_doc[:source_s]
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
      "#{@parent_id}_#{page_identifier}"
    end

    def parent_id_s
      id.sub(/_\d+$/, '')
    end

    def pdf_url_display
      [ 'http://nyx.uky.edu/dips',
        @parent_id,
        'data',
        @mets.print_image_path(@identifier)
      ].join('/')
    end

    def reference_image_url_s
      [ 'http://nyx.uky.edu/dips',
        @parent_id,
        'data',
        @mets.reference_image_path(@identifier)
      ].join('/')
    end

    def viewer_url_s
      [ 'http://nyx.uky.edu/dips',
        @parent_id,
        'data',
        @mets.viewer_path(@identifier)
      ].join('/')
    end

    def sequence_number_display
      @mets.sequence_number @identifier
    end

    def page_identifier
      @mets.order_path(@identifier).join('_')
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

    def text_s
      text
    end

    def text_href
      @mets.text_href @identifier
    end
  end
end

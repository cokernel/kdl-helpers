require 'nokogiri'

module KDL
  class Page
    attr_reader :identifier
    attr_reader :solr_doc

    def initialize(mets, identifier, parent_id, dip_directory, solr_doc, finding_aid=false)
      @mets = mets
      @identifier = identifier
      @parent_id = parent_id
      @dip_directory = dip_directory
      @solr_doc = solr_doc
      @title = solr_doc[:title_display]
      @finding_aid = finding_aid
    end

    def save(solr_directory)
      FileUtils.mkdir_p(solr_directory)
      solr_file = File.join(solr_directory, id)
      File.open(solr_file, 'w') { |f|
        f.write page_fields.to_json
      }
    end

    def page_fields
      hash = Hash.new
      if finding_aid?
        hash = finding_aid_fields
      else
        hash = paged_page_fields
      end
      hash[:browse_key_sort] = browse_key_sort
      hash.each_pair do |key, value|
        if value.class == String
          hash[key] = value.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').strip.gsub(/\.\.$/, '.')
        end
      end
      hash
    end

    def finding_aid_xml
      Nokogiri::XML(
        IO.read(
          File.join(
            @dip_directory,
            'data',
            @mets.href(:fileGrp_use => 'Finding Aid',
                       :file_use => 'access'))))
    end

    def has_finding_aid?
      begin
        ref = @mets.href(:fileGrp_use => 'Finding Aid',
                   :file_use => 'access')
        return(ref and ref.length > 0)
      rescue
        false
      end
    end

    def finding_aid_fields
      fields = @solr_doc.dup
      fields[:title_guide_display] = fields[:title_sort]
      [
        :id,
        :text,
        :text_s,
      ].each do |page_field|
        fields[page_field] = send(page_field)
      end
      unless fields[:source_s].nil?
        fields[:text] += fields[:source_s]
      end
      fields[:unpaged_display] = true
      fields[:format] = 'collections'
      fields
    end

    def container_type(container)
      bad_types = ['folder/item', 'othertype']
      candidates = [container['type'], container['label'], 'folder']
      candidates.compact.collect {|candidate|
        candidate.downcase.strip
      }.reject {|candidate|
        bad_types.include? candidate
      }.first
    end

    def paged_page_fields
      the_label = 
      if page_type == 'sequence'
        sequence_number_display
      else
        label_display
      end
      label_path = @mets.label_path @identifier
      label_path.pop
      fields = @solr_doc.dup
      if the_label =~ /^\[?\d+\]?$/
        label_path.push "#{page_type.sub(/^(\w)/){|c|c.capitalize}} #{the_label}"
        fields[:title_display] = "#{label_path.join(' > ')} of #{@title}"
      else
        label_path.push "#{the_label}"
        fields[:title_display] = the_label.sub(/\s*([,.;:!?]+\s*)+$/, '')
      end
      #label_path.push "#{page_type.capitalize} #{the_label}"
      #if the_label =~ /^\d+$/
      #  fields[:title_display] = "#{label_path.join(' > ')} of #{@title}"
      #else
      #  fields[:title_display] = "#{the_label}".sub(/\s*([,.;:!?]+\s*)+$/, '')
      ##end
      fields[:title_guide_display] = fields[:title_sort]
      fields[:title_t] = fields[:title_display]
      [
        :id,
        :label_display,
        :sequence_number_display,
        :sequence_sort,
        :text,
        :text_s,
        :reference_image_url_s,
        :thumbnail_url_s,
        :front_thumbnail_url_s,
        :viewer_url_s,
        :pdf_url_display,
        :parent_id_s,
        :coordinates_s,
        :reference_audio_url_s,
        :secondary_reference_audio_url_s,
      ].each do |page_field|
        fields[page_field] = send(page_field)
      end
      unless fields[:source_s].nil?
        fields[:text] += fields[:source_s]
      end
      if has_finding_aid?
        if fields[:reference_audio_url_s] and fields[:reference_audio_url_s].length > 0
          fields[:format] = 'audio'
        elsif page_type == 'photograph'
          fields[:format] = 'images'
        else 
          fields[:format] = 'archival material'
        end
        if fields.has_key?(:id) and fields[:id]
          tag = fields[:id].dup
          if finding_aid_xml.xpath("//xmlns:dao[@entityref='#{tag}']").count == 0
            tag.gsub!(/_\d+$/, '_1')
          end
          containers = finding_aid_xml.xpath("//xmlns:dao[@entityref='#{tag}']/../xmlns:container").collect do |container|
            content = container.content.strip
            structure = container_type container
            %-#{structure} #{content}-
          end
          fields[:container_list_s] = containers.join(', ')
        end
        if fields.has_key?(:id) and fields[:id]
          tag = fields[:id]
          begin
            subjects = finding_aid_xml.xpath("//xmlns:dao[@entityref='#{tag}']/../..//xmlns:subject").collect do |subject|
              subject.content
            end
            fields[:subject_topic_facet] = subjects.flatten.uniq
          rescue
          end

          begin
            unitdate = finding_aid_xml.xpath("//xmlns:dao[@entityref='#{tag}']/../..//xmlns:unitdate").first.content

            if unitdate =~ /\d\d\d\d/
              fields[:pub_date] = unitdate.sub(/.*(\d\d\d\d).*/, '\1')
            end
          rescue
          end

          begin
            fields[:accession_number_s] = finding_aid_xml.xpath("//xmlns:unitid").first.content.downcase.sub(/^kukav/, '')
          rescue
          end

          begin
            fields[:contributor_s] = finding_aid_xml.xpath("//xmlns:dao[@entityref='#{tag}']/../..//xmlns:origination[@label='contributor']").first.content
          rescue
          end

          begin
            author = finding_aid_xml.xpath("//xmlns:dao[@entityref='#{tag}']/../..//xmlns:origination[@label='creator']").first.content
            fields[:author_t] = author
            fields[:author_display] = author
          rescue
          end
        end
      end
      # trim nil fields
      fields.keys.each do |key|
        if fields[key].nil? 
          fields.delete key
        end
      end
      fields
    end

    def page_title
      if sequence_number_display.to_i > 1
        "#{type.capitalize} #{label_display}"
      else
        @solr_doc[:title_t]
      end
    end

    def browse_key_sort
      begin
        "#{@solr_doc[:title_processed_s][0..0]}#{sequence_sort} #{@solr_doc[:title_processed_s]}"
      rescue
        ''
      end
    end

    def id
      if finding_aid?
        @parent_id
      else
        "#{@parent_id}_#{page_identifier}"
      end
    end

    def parent_id_s
      id.sub(/_\d+$/, '')
    end

    def dip_field(method)
      path = @mets.send(method, @identifier)
      if path.length > 0
        [ 'http://nyx.uky.edu/dips',
          @parent_id,
          'data',
          path
        ].join('/')
      end
    end

    def pdf_url_display
      dip_field(:print_image_path)
    end

    def reference_image_url_s
      dip_field(:reference_image_path)
    end

    def thumbnail_url_s
      dip_field(:thumbnail_path)
    end

    def front_thumbnail_url_s
      dip_field(:front_thumbnail_path)
    end

    def reference_audio_url_s
      dip_field(:reference_audio_path)
    end

    def secondary_reference_audio_url_s
      dip_field(:secondary_reference_audio_path)
    end

    def viewer_url_s
      dip_field(:viewer_path)
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
      if finding_aid? and @solr_doc.has_key?(:text)
        @solr_doc[:text]
      else
        begin
          IO.read(File.join(@dip_directory, 
                            'data', 
                            text_href))
        rescue
          ''
        end
      end
    end

    def text_s
      text
    end

    def text_href
      @mets.text_href @identifier
    end

    def alto
      file = @mets.alto_href @identifier
      if file.length > 0
        @alto = Nokogiri::XML(
                  IO.read(File.join(@dip_directory,
                                    'data',
                                    file)))
      end
    end

    def coordinates_s
      JSON.dump coordinates_hash
    end

    def coordinates_hash
      coordinates = Hash.new
      xml = alto
      if xml
        resmod = resolution.to_f / 1200
        xml.css('String').each do |string|
          content = string.attribute('CONTENT').text.downcase.strip
          content.gsub!(/\W/, '')
          coordinates[content] ||= []
          coordinates[content] << [ 'WIDTH',
            'HEIGHT',
            'HPOS',
            'VPOS' ].collect do |attribute|
            string.attribute(attribute).text.to_f * resmod
          end
        end
      end
      coordinates
    end

    def resolution
      if @resolution.nil?
        file = @mets.reel_metadata_href
        if file
          xml = Nokogiri::XML(
                  IO.read(File.join(@dip_directory,
                                    'data',
                                    file)))
          @resolution = xml.xpath('//ndnp:captureResolutionOriginal').first.content.to_i
        else
          begin
            @resolution = @mets.base_resolution 
          rescue
            @resolution = 300
          end
        end
      end
      @resolution
    end

    def finding_aid?
      @finding_aid
    end
  end
end

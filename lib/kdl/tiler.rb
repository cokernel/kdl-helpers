module KDL
  class Tiler
    def initialize(output)
      @output = output
      @initialized = false 
      @options = Hash.new
    end

    def configure(options=nil)
      @options.merge!(options)
      required_keys = [
        :input_directory,
        :output_directory,
        :no_move,
        :quiet,
      ]
      if options
        @initialized = true
        required_keys.each do |key| 
          unless @options.has_key?(key)
            @initialized = false
          end
        end
      end
    end

    def run
      if @initialized
        Open3.popen3(command) do |input, output, errors|
          output.each { |line| @output.puts(line) }
          errors.each { |line| @output.puts(line) }
        end
      else
        @output.puts("The tiler must be initialized before it can be used.")
      end
    end

    def command
      bits = ['/usr/local/bin/tiler.py']
      if @options[:input_directory]
        bits << "--input-directory=#{@options[:input_directory]}"
      end
      if @options[:output_directory]
        bits << "--output-directory=#{@options[:output_directory]}"
      end
      if @options[:no_move].class == TrueClass
         bits << "--no-move"
      end
      if @options[:delete].class == TrueClass
         bits << "--delete"
      end
      if @options[:quiet].class == TrueClass
         bits << "--quiet"
      else
         bits << "--verbose"
      end
      if @options[:make_pdfs].class == FalseClass
         bits << "--no-pdfs"
      else
         bits << "--make-pdfs"
      end
      # optional arguments
      if @options[:file]
         bits << "--file=#{@options[:file]}"
      end
      bits.join(' ')
    end
  end
end

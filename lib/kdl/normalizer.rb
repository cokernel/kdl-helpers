module KDL
  module Normalizer
    def normalize thing
      # I know it is not idiomatic Ruby
      # to care about specific classes.
      #
      # However, my use case specifically involves
      # a Hash whose values are known to be Arrays (of String),
      # Strings, TrueClasses, and FalseClasses.
      if thing.class == Hash
        result = {}
        thing.each_pair do |key, value|
          result[key] = normalize value
        end
        result
      elsif thing.class == Array
        thing.collect do |item|
          normalize item
        end
      elsif thing.class == String
        thing.tr("\u0000-\u001f\u007f\u0080-\u009f", ' ').gsub(/\s+/, ' ')
      else
        thing
      end
    end
  end
end

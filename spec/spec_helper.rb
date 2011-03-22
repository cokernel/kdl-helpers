require 'open3'
require 'rubygems'
require 'bagit'
require 'find'
require 'json'
require 'kdl'
require 'lorax'
require 'nokogiri'
require 'pathname'
require 'rails'

require 'tempfile'

class Sandbox

  def initialize
    tf = Tempfile.open 'sandbox'
    @path = tf.path
    tf.close!
    FileUtils::mkdir @path
  end

  def cleanup!
    FileUtils::rm_rf @path
  end

  def to_s
    @path
  end

end

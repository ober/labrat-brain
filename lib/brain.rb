$:.unshift(File.expand_path("../brain", __FILE__))
require "version"
require "thor/vcr" if ENV['VCR'] == '1'
require 'aws-sdk'
require 'yaml'

module Brain
  autoload :Firewall, 'firewall'
  autoload :Helper, 'helper'
  autoload :UI, 'ui'
end

require 'thor'
require 'cli/help'

module Brain

  class CLI < Thor
    class_option :noop, :type => :boolean
    class_option :verbose, :aliases => :v, :type => :boolean

    desc "firewall", "scan firewall"
    long_desc Help.firewall
    option :limit, :type => :numeric, :aliases => :l, :desc => 'limit number of servers to scan, useful for quick testing'
    option :concurrency, :type => :numeric, :aliases => :c, :desc => 'number of concurrent threads to use, dont recommend over 40', :default => 20
    option :nmap, :desc => "nmap options, make sure to put space in front: ' -Pn'", :default => ' -Pn'
    option :report_file, :type => :boolean, :desc => "generate report file in tmp folder", :default => true
    def firewall
      Firewall.new(options).run
    end
  end
end

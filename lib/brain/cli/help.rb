module Brain
  class CLI < Thor
    class Help
      class << self
        def firewall
<<-EOL
Examples:

$ bin/brain firewall -l 30 --nmap '-sT -P0' -v

$ bin/brain firewall -c 10 -l 30 --nmap ' -sT' -v
EOL
        end
      end
    end
  end
end

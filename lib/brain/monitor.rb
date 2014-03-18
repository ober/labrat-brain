module Monitor
  class JsonHandling
    @ping_from = "prod-webserver" # servers from which to perform the pings
    @alert_dir = "/data/brain-monitoring/alerts"

    @args_def =
      {
       :metric     => "The name of the metric as seen in :list task",
       :count      => "Get the :count most recent data points",
       :source     => "Name of system to display the metrics for",
       :limit      => "Threshold for displaying metrics"
      }

    @alert_email = "ops@linbsd.org"

    def with_custom_monitor(monitor,concurrency,filter,extra,&block)
      Dir.mktmpdir do |d|
        Dir.chdir d do
          url = extra ? monitor + extra : monitor
          %x{/data/labrat/labrat -s='/data/ec2read/production/servers.txt' -u="/pinky/#{url}" -c="#{concurrency}"}
          with_standard_monitor(monitor,d) do |data,name,json|
            yield(data,name,json)
          end
        end
      end
    end

    def with_history_monitor(metric, last, limit, pagerate, &block)
      Librato::Metrics.fetch(metric.to_sym, :start_time => (Time.now - (ENV['last'].to_i * 60)) ).each_pair do |k,v|
        yield(k,v)
      end
    end

    def with_standard_monitor(pattern,dir,&block)
      Dir.glob("#{dir}/*#{pattern}.json") do |json|
        begin
          data = JSON.parse(File.read(json))
          name = data['system']['name'] if data and data['system'] and data['system']['name']
          name ||= json.split("-#{pattern}.json").to_s.split("/").last.gsub(/\"/,'').gsub(/\]/,'')
          if data and data['status'] and ( data['status']['value'] == "OK" or data['status']['value'] == "FAIL")
            yield(data,name,json)
            %{mv #{json} /tmp/broken}
          end
        rescue Exception => e
          puts "Invalid json. Could not read #{json} #{e.message}"
        end
      end
    end

    def librato_fetch(metric,count,&block)
      Librato::Metrics.fetch(metric.to_sym, :count => count.to_i).each do |l|
        yield(l)
      end
    end

    desc "Monitor Mysql Slave Delay"
    task :slave_delay do
      paging = false
      results = ""
      hosts = 0
      ensure_args [ :count, :threshold, :times, :quorum ]
      librato_fetch("prod_mysql_slave_delay", ENV['count']) do |l|
        host,data = l[0],l[1]

        if data.last['value'].to_i >= ENV['threshold'].to_i
          #determine if we've been over threshold for ENV['times'] and
          #alert if so.
          count = data.select {|x| x["value"].to_i > ENV['threshold'].to_i }.count
          results << " #{host} @data.last['value'].to_i #{count}/#{ENV['times']}"
          hosts += 1
        end
      end

      unless results.empty? and hosts > ENV['quorum'].to_i
        if should_i_page?("slave_delay","db",180)
          puts "yes"
          send_pagerduty(results)
          %x{ echo "#{results}"|mail -s "Alert #{results}" ops@linbsd.org}
        end
      end
    end

    def send_pagerduty(msg)
      puts "Paging!"
      org = "Pinky"
      uri = URI.parse("https://events.pagerduty.com/generic/2010-04-15/create_event.json")
      header = { 'Content-Type' => 'application/json' }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(uri.request_uri, header)

      body = {
              :service_key => "ba3a48c0dd19479ea1470ee9eed7400d",
              :incident_key => org,
              :event_type => "trigger",
              :description => msg
             }

      request.body = body.to_json
      File.open("/tmp/fypd","w+"){|f|
        f.puts http.request(request)
      }
    end

    def sendmail(message, from, to, subject)
      msg = <<EOF
From: #{from}
To: #{to}
Subject: #{subject}
Date: #{Time.now.to_s}
Message-Id: <labrat.message.id.#{Time.now.to_i}@linbsd.org>
EOF
      msg << message

      Net::SMTP.start('localhost') do |smtp|
        smtp.send_message msg, from, to
      end
    end

    task :default do
      puts `rake --tasks`
    end

    def perror msg
      puts "Error: #{msg}"
      exit 2
    end

    @authfile = "#{ENV['HOME']}/.librato.yml"

    def update_alert_file(alert,host,wait)
      File.open("#{@alert_dir}/#{alert}-#{host}","w+").write Time.now.to_i
    end

    def time_in_range?(last_time,wait)
      (Time.now.to_i - last_time)  < (wait.to_i * 60) ? true : false
    end

    # should_i_page? takes name of alert, name of host, and how long to
    # wait in minutes before repaging on a given issue.
    def should_i_page?(alert,host,wait)
      Dir.mkdir(@alert_dir) unless File.exists?(@alert_dir)
      if File.exists?("#{@alert_dir}/#{alert}-#{host}")
        if time_in_range?(File.read("#{@alert_dir}/#{alert}-#{host}").to_i, wait)
          false
        else
          update_alert_file(alert,host,wait)
          true
        end
      else
        update_alert_file(alert,host,wait)
        true
      end
    end

    desc "test should_i_page"
    task :test_should_i_page do
      puts should_i_page?(ENV['alert'],ENV['host'], ENV['wait'])
    end

    def ensure_args(args)
      out = ""
      args.uniq.map { |a| out << "\n\t #{a}=<#{a}> #{@args_def[a].to_s}" unless ENV[a.to_s]  }
      perror "\nArguments required: #{out}" unless out.empty?
    end

    if File.exists?(@authfile)
      @config = YAML.load(File.open(@authfile))
      Librato::Metrics.authenticate @config["email"], @config["api_token"]
    else
      puts "No #{@authfile} exists! Exiting"
      exit(2)
    end

    desc "Fetch Values: (metric, count)"
    task :get do
      ensure_args [:metric, :count ]
      Librato::Metrics.fetch(ENV['metric'].to_sym, :count => ENV['count'].to_i).each do |l|
        puts l
      end
    end

    desc "List Available Metrics"
    task :list do
      Librato::Metrics.list.each do |l|
        puts l["name"]
      end
    end

    def get_metrics(metric,count,limit,mpattern)
      puts "#{__method__} #{metric} #{count} #{limit} #{mpattern}"
      count = 2 if count.to_i < 2
      Librato::Metrics.fetch(metric, :count => count).each_pair do |k,v|
        out = []
        v.each do |w|
          if out.empty?
            out << 0
          else
            last ||= w['value']
            out << last - w['value']
          end
          if mpattern
            puts "YY #{k} #{out}" if w['value'] > limit.to_i if /#{mpattern}/.match(k)
          else
            puts "XX #{k} #{out}" #if diff > limit.to_i
          end
        end
      end
      out
    end

    desc "Get metrics over a given limit for current aggregate value"
    task :get_limit do
      ensure_args [:metric, :limit, :count ]
      count = 2 if ENV['count'].to_i < 2
      puts get_metrics(ENV['metric'], ENV['count'], ENV['limit'], ENV['pattern'])
    end

    @production_mysql = {
                         :prod_br_db_master => '10.30.143.91',
                         :prod_br_db_slave1 => '10.140.1.147',
                         :prod_br_db_slave2 => '10.218.93.167',
                         :prod_br_db_slave3 => '10.218.95.219',
                         :prod_br_db_slave4 => '10.31.138.97',
                         :prod_br_db_slave5 => '10.44.117.70',
                         :prod_br_db_slave6 => '10.31.129.17',
                         :prod_br_db_slave7 => '10.149.46.47',
                         :prod_br_db_slave8 => '10.171.0.118',
                         :prod_br_db_slave9 => '10.150.8.137',
                         :prod_br_db_slave10 => '10.78.174.109',
                         :prod_br_db_slave11 => '10.126.142.14',
                         :prod_br_db_slave_bg => '10.171.0.118',
                         #:prod_bogus_db_server => '10.171.0.222'
                        }

    desc "Check Database connectivity from "
    task :mon_db_ping do
      results = {}
      @production_mysql.each_pair do |n,i|
        results[n.to_sym] = {
                             :failures_out => "",
                             :pass_ok => "",
                             :pingers => 0,
                             :passed => 0,
                             :failed => 0,
                             :hosts_passed => [],
                             :hosts_failed => []
                            }
        Dir.mktmpdir do |dir|
          puts %x{~/ec2read/generate_app_list #{@ping_from} > #{dir}/servers.txt}
          puts %x{cd #{dir} && /data/labrat/labrat -c=100 -u="/pinky/ping/#{i}" }
          with_standard_monitor("ping",dir) do |data,name,json|
            results[n.to_sym][:pingers] += 1
            if data['status']['value'] == "OK"
              results[n.to_sym][:hosts_passed] << name
              results[n.to_sym][:passed] += 1
              results[n.to_sym][:pass_ok] << "\n#{data['data']} #{data['status']}"
            else
              results[n.to_sym][:hosts_failed] << name
              results[n.to_sym][:failed] += 1
              results[n.to_sym][:failures_out] << "\n#{data['data']} #{data['status']}"
            end
          end
        end
      end
      File.open("/data/brain-monitoring/logs/#{Time.now.to_i}.yml","w").write(results.to_yaml)
      out = ""
      unless results.select{|k,v| v[:failed] != 0 }.empty?
        results.select{|k,v| v[:failed] != 0}.each_pair do |k,v|
          msg = "Mysql Server down: #{k} not pingable by #{v[:failed]} out of #{v[:pingers]}"
          send_pagerduty(msg) if ENV['alert'] == "yes" or ENV['alert'] == "true"
          out << "\n\n#{k} Failed #{v[:failed]} out of #{v[:pingers]}: failed hosts: #{v[:hosts_failed].sort.join(" \n")}"
        end
      else
        results.select{|k,v| v[:failed] == 0}.each_pair do |k,v|
          out << "\n\n#{k} Passed #{v[:passed]} out of #{v[:pingers]} Passed hosts: #{v[:hosts_failed].sort.join(" \n")}"
        end
      end
      #sendmail(out, "labrat@bleachherreport.com", @alert_email, "Ping: MySQL ping report")
      puts "Sent!"
    end

    desc "send test page"
    task :test_page do
      send_pagerduty("test page")
    end

    desc "Monitor for 5xx on ELB"
    task :elb_mon do
      ensure_args [ :last, :limit ]
      metric = "AWS.ELB.HTTPCode_Backend_5XX"
      with_history_monitor(metric, ENV['last'], ENV['limit'], ENV['pagerate']) do |k,v|
        total = 0
        v.each do |line|
          total += line['value'].to_i
        end
        puts "#{k} with total:#{total.to_i}"
        if total > ENV['limit'].to_i
          if should_i_page?("elb 500 alert on #{k}","elb",180)
            send_pagerduty("ELB 5XX alert on #{k}. Currently at #{total} over threshold of #{ENV['limit']}")
          end
        end
      end
    end

    desc "Monitor memory below 10%"
    task :mem_mon do
      with_standard_monitor("memfree","/data/ec2read/production") do |data,name,json|
        msg = "Real Memory below 10% on host #{name}"
        perfree = (data['data']['bc_free'].to_f/data['data']['total'].to_f * 100).to_i
        if perfree <= 10 and /^prod-br-app/.match(name)
          if should_i_page?(memory,name,180) #don't page on same
            #host/issue more than once an hour
            %x{ echo "#{msg}"|mail -s "Alert #{msg}" jaimef@linbsd.org}
            send_pagerduty(msg)
          end
        end
      end
    end

    desc "Monitor chap differences"
    task :mon_chap do
      sizes,offenders = Set.new,[]
      with_custom_monitor("stat", "100", "prod-br*", "/etc/chef/chap.json") do |data,name,json|
        if data["status"]["value"] == "OK" and /^prod-br-/.match(name)
          size_first = sizes.size
          sizes.add(data["data"]["size"])
          size_last = sizes.size
          offenders << name if size_first != 0 && size_last > size_first
        end
      end
      if !offenders.empty? && should_i_page?("chap_json","file",360)
        puts "offenders:#{offenders.join('\n')}"
        sendmail("The following hosts have different chap.json files: #{offenders.join(",")}", "labrat@bleachherreport.com", @alert_email, "Chap.json alert")
      end
    end

    desc "Monitor SSH Key Root differences"
    task :ssh_root_key_diff do
      md5s,offenders,all = Set.new,[],[]
      with_custom_monitor("md5sum", "100", "*", "/root/.ssh/authorized_keys") do |data,name,json|
        all <<  name
        if data["status"]["value"] == "OK"
          md5s_first = md5s.size
          md5s.add(data["data"].split[0])
          md5s_last = md5s.size
          offenders << name if md5s_first != 0 && md5s_last > md5s_first
        end
      end
      if !offenders.empty? && should_i_page?("root_ssh_key","file",360)
        puts "offenders:#{offenders.join('\n')}"
        sendmail("The following hosts have different /root/.ssh/authorized_keys files: #{offenders.join(",")}", "labrat@bleachherreport.com", @alert_email, "FAIL: root ssh authorized_keys alert")
      else
        puts "No Offenders found"
        sendmail("All ssh keys match #{all.join(',')}", "labrat@bleachherreport.com", @alert_email, "OK: root ssh keys all match")
      end
    end

    desc "Monitor SSH Key Ubuntu differences"
    task :ssh_ubuntu_key_diff do
      md5s,offenders = Set.new,[]
      with_custom_monitor("md5sum", "100", "*", "/home/ubuntu/.ssh/authorized_keys") do |data,name,json|
        if data["status"]["value"] == "OK"
          md5s_first = md5s.size
          md5s.add(data["data"].split[0])
          md5s_last = md5s.size
          offenders << name if md5s_first != 0 && md5s_last > md5s_first
        end
      end
      if !offenders.empty? && should_i_page?("ubuntu_ssh_key","file",360)
        puts "offenders:#{offenders.join('\n')}"
        sendmail("The following hosts have different /home/ubuntu/.ssh/authorized_keys files: #{offenders.join(",")}", "labrat@bleachherreport.com", @alert_email, "FAIL: ubuntu ssh authorized_keys alert")
      else
        puts "No Offenders found"
        sendmail("All ssh keys match", "labrat@bleachherreport.com", @alert_email, "OK: ubuntu ssh keys all match")
      end
    end

    desc "Monitor SSH Key Deploy differences"
    task :ssh_deploy_key_diff do
      md5s,offenders = Set.new,[]
      with_custom_monitor("md5sum", "200", "*", "/home/deploy/.ssh/authorized_keys") do |data,name,json|
        if data["status"]["value"] == "OK"
          md5s_first = md5s.size
          md5s.add(data["data"].split[0])
          md5s_last = md5s.size
          offenders << name if md5s_first != 0 && md5s_last > md5s_first
        end
      end
      if !offenders.empty? && should_i_page?("deploy_ssh_key","file",360)
        puts "offenders:#{offenders.join('\n')}"
        sendmail("The following hosts have different /home/deploy/.ssh/authorized_keys files: #{offenders.join(",")}", "labrat@bleachherreport.com", @alert_email, "FAIL: deploy ssh authorized_keys alert")
      else
        puts "No Offenders found"
        sendmail("All ssh keys match", "labrat@bleachherreport.com", @alert_email, "OK: deploy ssh keys all match")
      end
    end
  end
end

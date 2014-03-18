module Brain
  module Helper
    def setup_aws(options={})
      path = ENV['AWS'] || File.expand_path("../../../config/aws.yml", __FILE__)
      config = YAML.load_file(path)
      options = {
        :access_key_id => config[:aws_access_key_id],
        :secret_access_key => config[:aws_secret_access_key]
      }.merge(options)
      AWS.config(options)
      AWS.start_memoizing
    end

    def reset_memoization
      AWS.reset_memoization
    end

    @@ec2 = {}
    def ec2(region='us-east-1')
      @@ec2[region] ||= AWS::EC2.new(:region => region)
    end
  end
end

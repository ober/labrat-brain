module Brain
  class Collector
    include Helper

    def initialize(options={})
      @options = options
      @limit = options[:limit]-1 if @options[:limit]
      @concurrency = options[:concurrency] || 100
      @results = {}
      setup_labrat(options)
    end

    def run

    end
  end
end

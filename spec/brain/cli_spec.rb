require 'spec_helper'

# to run specs with what's remembered from vcr
#   $ rake
#
# to run specs with new fresh data from aws api calls
#   $ rake clean:vcr ; time rake
describe Brain do
  before(:all) do
    @args = "--noop -l 5 --report-file false"
  end

  describe "brain" do
    it "scan firewall for open ports" do
      out = execute("bin/brain firewall #{@args}")
      out.should include("Scanning firewall")
    end
  end
end

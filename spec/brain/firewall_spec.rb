require 'spec_helper'

describe Audit::Firewall do
  before(:all) do
    @options = {
      :limit => 5,
      :report_file => false
    }
    # Audit::UI.mute = true
  end

  let(:firewall) { Audit::Firewall.new(@options) }

  before(:each) do
    firewall.stub(:nmap).and_return(
      "22/tcp open  ssh\n80/tcp open  http\n",
      "22/tcp open  ssh\n81/tcp open  http\n"
    )
  end

  describe "run" do
    it "report open ports" do
      results = firewall.run
      key = results.keys.first
      r = results[key]
      r[:ports].should be_a(Array)
      r[:security_groups].should be_a(Array)
    end
  end
end

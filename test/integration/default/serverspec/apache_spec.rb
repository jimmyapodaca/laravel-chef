require 'serverspec'

# Required by serverspec
set :backend, :exec

describe "Apache web server" do
  it "is listening on port 80" do
    expect(port(80)).to be_listening
  end

  it "is listening on port 443" do
    expect(port(443)).to be_listening
  end
end

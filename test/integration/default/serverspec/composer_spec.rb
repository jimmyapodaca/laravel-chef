require 'serverspec'

# Required by serverspec
set :backend, :exec

describe file("/srv/composer.json") do
  it { should be_file }
end

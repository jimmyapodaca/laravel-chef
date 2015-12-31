#
# Cookbook Name:: laravel
# Recipe:: laravel
#
# Copyright 2014, Michael Beattie
#
# Licensed under the MIT License.
# You may obtain a copy of the License at
#
#     http://opensource.org/licenses/MIT
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Laravel::Helpers)
path = project_path

package "git"

# Check if composer has been installed globally
if node['composer']['install_globally']
  composer_command = "composer"
else
  composer_command = "php composer"
end

if node['laravel']['version'] < 5
  storage = "app/storage"
  config = "app/config"
else
  storage = "storage"
  config = "config"
end

# Laravel requires this directory to have write access by the web server
execute "Chmod storage directory" do
  action :nothing
  command "sudo chmod -R 777 #{path}/#{storage}"
end


if !node['laravel']['github_oauth'].empty?
  # FIXME set this dynamically.
  user_home = "/root"

  composer_path = "#{user_home}/.composer"

  if !::File.directory?("#{composer_path}")
    execute "mkdir --parents #{composer_path}"
  end

  template "#{composer_path}/auth.json" do
    source "github-oauth.json.erb"
    mode "0644"
  end
end

# Check if the composer config files already exist
if ::File.exist?("#{path}/composer.json")

  # Update composer dependencies
  execute "Install Composer Packages" do
    action :run
    command "cd #{path}; #{composer_command} install"
  end

else
  # Create a new project if it does not already exist
  # Creates composer and other config files
  # Generates a new Laravel encryption key
  # This is assumed to be during new project creation

  # First, notify the user that they are creating a new project
  # We do this because creating a new project takes a while
  log "Creating #{node['laravel']['project_name']} ..."

  if node['laravel']['create_with_temp_folder']
    Dir.mktmpdir do |dir|
      execute "Create Laravel Project (with temp folder)" do
        action :run
        command "#{composer_command} create-project laravel/laravel #{dir} #{node['laravel']['version']}.* --prefer-dist"
        notifies :run, "execute[Chmod storage directory]"
      end

      ruby_block "move files from temp folder" do
        block do
          Dir.new(dir).each do |file|
            unless file == "." or file == ".."
              if File.exist?("#{path}/#{file}")
                FileUtils.rm "#{path}/#{file}"
              end
              puts "copying file #{dir}/#{file} to #{path}"
              FileUtils.copy_entry "#{dir}/#{file}", "#{path}/#{file}"
            end
          end
        end
        action :run
      end
    end
  else
    execute "Create Laravel Project" do
      action :run
      command "#{composer_command} create-project laravel/laravel #{path} #{node['laravel']['version']}.* --prefer-dist"
      notifies :run, "execute[Chmod storage directory]"
    end
  end

  template "#{path}/composer.json" do
    source "#{node['laravel']['version']}/composer.json.erb"
    variables(
      :recipes => node['recipes']
    )
    mode "0644"
  end

  template "#{path}/.env" do
    source "#{node['laravel']['version']}/.env.erb"
    variables(
      :host => node['laravel']['db']['host'],
      :name => node['laravel']['db']['name'],
      :user => node['laravel']['db']['user'],
      :password => node['laravel']['db']['password']
    )
    mode "0644"
    only_if { node['laravel']['version'] >= 5 }
  end

  # Update composer dependencies
  execute "Install Composer Packages" do
    action :run
    command "cd #{path}; #{composer_command} update"
  end

  template "#{path}/#{config}/app.php" do
    source "#{node['laravel']['version']}/app.php.erb"
    variables(
      :recipes => node['recipes']
    )
    mode "0644"
  end
end


include_recipe "laravel::database"
include_recipe "laravel::server"

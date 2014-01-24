require 'digest/md5'
require 'optparse'

require_relative '../cluster'
require_relative '../server'
require_relative '../app'
require_relative '../mongo'
require_relative '../file_helpers'
require_relative '../load_balanced'


options = { }
OptionParser.new do |opts|
 opts.banner = "Usage: replica-mongo.rb --port=27018 --set=repl2"
 opts.on('--port port', 'Set the port for the webapp') do |port|
   options[:port] = port
 end 
 opts.on('--clusterfile file', 'Sets the clusterfile name') do |clusterfile|
   options[:clusterfile] = clusterfile
 end 
 opts.on('--id app_id', 'Sets the app id') do |id|
   options[:id] = id
 end 
end.parse!

cluster = Cluster.load_from_file(options[:clusterfile])
zk = ZK.new(cluster.masters.collect{|x| x.external_address + ":2181" }.join(",") + "/webapps")

app_dir = "/" + Digest::MD5.hexdigest(options[:id]).to_s
install_dir = "/apps" + app_dir + port.to_s
git_key = app_dir + '-git'
version_key = app_dir + '-version'
type_key = app_dir + '-type'

type = zk.get(type_key)[0]
version = zk.get(version_key)[0]
git = zk.get(git_key)[0]

system 'mkdir -p /apps'
system 'rm -rf ' + install_dir
system 'git clone %s %s' % [git, install_dir]
Dir.chdir install_dir
system 'git checkout -- .'
system 'git checkout %s' % [version_key]
if type == 'rack'
  system 'bundle install'
  system 'bundle exec rackup -p %s' % [options[:port]]
end
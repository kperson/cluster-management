require 'digest/md5'
require 'optparse'

require_relative '../cluster'
require_relative '../server'
require_relative '../app'
require_relative '../file_helpers'

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
zk = ZK.new(self.cluster.masters.collect{|x| x.external_address + ":2181" }.join(",") + "/webapps")

def app_dir
  "/" + Digest::MD5.hexdigest(options[:id]).to_s
end

def install_dir
  "/apps" + app_dir
end

def git_key
  app_dir + '-git'
end

def version_key
  app_dir + '-version'
end  

def type_key
  app_dir + '-type'
end    

type = zk.get(type_key)
version = zk.get(version_key)
git = zk.get(git_key)

system 'mkdir -p /apps'
system 'git clone %s %s' % [git, install_dir]
Dir.chdir install_dir
if type == 'rack'
  system 'bundle install'
  system "rerun 'rackup -p %s'" % [options[:port]]
end
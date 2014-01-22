require 'zk'
require 'mustache'
require 'optparse'

require_relative '../cluster'
require_relative '../server'
require_relative '../app'
require_relative '../mongo'
require_relative '../file_helpers'

options = { }
OptionParser.new do |opts|
 opts.banner = "Usage: mongo-cluster.rb --dns ip-10-45-153-144.ec2.internal --id Mongo_rep1"
 opts.on('--dns internal_dns', 'The internal dns name') do |dns|
   options[:dns] = dns
 end 
 opts.on('--id app_id', 'Sets the mongo app id') do |app_id|
   options[:app_id] = app_id
 end  
 opts.on('--username username', 'Sets the mongo admin username') do |username|
   options[:username] = username
 end 
 opts.on('--password password', 'Sets the mongo admin passowrd') do |password|
   options[:password] = password
 end  
 opts.on('--clusterfile clusterfile', 'Sets the cluster file') do |clusterfile|
   options[:clusterfile] = clusterfile
 end   
end.parse!

cluster = Cluster.load_from_file(options[:clusterfile])

zk = ZK.new(cluster.masters.collect{|x| x.external_address + ":2181" }.join(",") + '/mongo')

mongo_endpoints = cluster.fetch_app_endpoints(options[:app_id])
running_nodes = mongo_endpoints.select{ |x| x[:server].internal_address == options[:dns] }[0]

barrier_lock = options[:app_id] + "-mongo-barrier"
master_check_lock = options[:app_id] + "-mongo-master-check"

def is_master(port)
  file_out = "/tmp/" + Time.now.to_i.to_s + port.to_i.to_s
  master_command = "mongo --port %s --nodb --eval '%s' > %s" % [port, FileHelpers.read_file_at('../mongo-scripts/is_master.js'), file_out]
  puts master_command
  system master_command
  FileHelpers.read_file_at(file_out).split("\n")[2] == 'true'
end

def configure_replica(mongo_endpoints, username, password, port)
  bind = { :endpoints => mongo_endpoints, :username => username, :password => password }
  template = FileHelpers.read_file_at('../mongo-scripts/replicate.js.mustache')
  replica_file = "/tmp/mongo-" + port.to_s + ".js"
  FileHelpers.write_file_at(replica_file, Mustache.render(template, bind))
  configure_command = "mongo --port %s < %s" % [port, replica_file]
  puts configure_command
  system configure_command
end

master_found = false
running_nodes[:ports].each do |port|
  shared_lock = zk.shared_locker(master_check_lock)
  shared_lock.lock!
  if !master_found && is_master(port)
    master_found = true
    replica_lock = zk.exclusive_locker(barrier_lock)
    replica_lock.lock!
    shared_lock.unlock!
    cconfigure_replica(mongo_endpoints, options[:username], options[:password], port)
    replica_lock.unlock!
  else
    shared_lock.unlock!
  end
end

if !master_found
  zk.with_lock(master_check_lock) do 
    replica_lock = zk.exclusive_locker(barrier_lock)
    if replica_lock.lock!
      configure_replica(mongo_endpoints, options[:username], options[:password], running_nodes[:ports][0])
      replica_lock.unlock!
    end
  end
end
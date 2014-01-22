require 'yaml'

require_relative 'file_helpers'
require_relative 'app'

class Mongo < App

  def self.MongoCluster(app_id, rep_set, cluster, cpus = 1.0, ram = 512)
    app = Mongo.new(app_id, cluster, cpus, ram)
    app.command = 'cd /install && sudo /usr/local/bin/ruby /install/replica-mongo.rb --port $PORT --set %s --fork false' % [rep_set]
    app
  end

  def replicate
    host_file = "/tmp/" + (0...25).map { (65 + rand(26)).chr }.join
    InventoryGenerator.new({ :all => self.instances.collect{|x| x[:server] } }).generate(host_file)
    clusterfile = "/install/cluster.yml"
    playbook_file = "/tmp/" + (0...25).map { (65 + rand(26)).chr }.join + ".yml"
    base_host_file = (0...25).map { (65 + rand(26)).chr }.join + ".yml"
    abs_host_file = "/tmp/" + base_host_file
    self.cluster.sync(abs_host_file)
    playbook = [{ 'hosts' => 'all', 'tasks' => [
      { 'name' => 'copy cluster file',  'copy' => 'src=%s dest=%s' % [base_host_file, clusterfile] },
      { 'name' => 'ensure mongo replication',  'command' => '/install/cluster-management/server-side/mongo-cluster.rb --id {{ app_id }} --dns {{ internal_dns }} --username {{ username }} --password {{ password }}' }
    ]}]
    FileHelpers.write_file_at(playbook_file, YAML.dump(playbook))
    username = 'username'
    password = 'password'
    command = 'ansible-playbook %s -i %s --extra-vars "id=%s username=%s password=%s clusterfile=%s"' % [playbook_file, host_file, self.app_id, username, password, clusterfile]
    system command
  end

  def app_type
    'mongo'
  end

end
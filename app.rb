require 'json'

class App

  attr_accessor :app_id, :instances, :cluster, :cpus, :ram, :command, :app_type

  def initialize(app_id, cluster, cpus = 1.0, ram = 512)
    self.app_id = app_id
    self.instances = instances
    self.cluster = cluster
    self.cpus = cpus
    self.ram = ram
    if self.cluster.apps.select{|x| x.app_id == app_id}.length == 0
      self.cluster.apps << self
    end
    self.recheck_instances
  end

  def start(num_nodes)
      puts "Starting app %s with command '%s' with %s nodes" % [self.app_id, self.command, num_nodes]
      start_endpoint = '%s%s' % [self.cluster.api_endpoint, 'v1/apps/start']
      conn = Faraday.new
      resp = conn.post do |req|
        req.url start_endpoint
        req.headers = { 'Content-Type' => 'application/json' }
        req.body = JSON.dump({ 'id' => self.app_id, 'instances' => num_nodes, 'cmd' => command, 'mem' => self.ram, 'cpus' => cpus })       
      end
      self.recheck_instances(1)
  end

  def scale(num_nodes)
    if !self.cluster.app_exists?(self.app_id)
      self.start(num_nodes)
    elsif self.num_nodes != num_nodes
      scale_action(num_nodes)
    end
  end

  def scale_action(num_nodes)
    puts "Scaling app %s from %s to %s" % [self.app_id, self.num_nodes, num_nodes]
    scale_endpoint = '%s%s' % [self.cluster.api_endpoint, 'v1/apps/scale']
    conn = Faraday.new
    resp = conn.post do |req|
      req.url scale_endpoint
      req.headers = { 'Content-Type' => 'application/json' }
      req.body = JSON.dump({ 'id' => self.app_id, 'instances' => num_nodes })       
    end 
    self.recheck_instances(1)   
  end

  def recheck_instances(delay = 0)
    sleep(delay)
    instances = self.cluster.fetch_app_endpoints(self.app_id)
    self.instances = instances
  end

  def total_cpu
    self.cpus * self.num_nodes
  end

  def total_ram
    self.ram * self.num_nodes
  end

  def num_nodes
    count = self.instances.collect{|x| x[:ports].length }.inject(:+)
    count ? count : 0
  end

  def app_type
    'generic'
  end  

end
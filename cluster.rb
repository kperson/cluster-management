require 'yaml'
require 'fileutils'
require 'faraday'
require 'json'

require_relative 'app'

class Cluster

  attr_accessor :servers, :aws_key, :aws_secret, :apps

  def initialize(servers, aws_key, aws_secret)
    self.servers = servers
    self.aws_key = aws_key
    self.aws_secret = aws_secret
    self.apps = []
  end

  def masters
    self.servers.select{|x| x.is_master == true }
  end

  def slave_only
    self.servers.select{|x| x.is_master == false }
  end

  def server_from_internal_address(internal_address)
    self.servers.select{ |x| x.internal_address == internal_address }[0]
  end

  def self.new_cluster(aws_key, aws_secret)
    Cluster.new([], aws_key, aws_secret)
  end

  def self.load_from_file(input_file)
    YAML.load(Cluster.read_file_at(input_file))
  end

  def sync(output_file)
    Cluster.write_file_at(output_file, YAML.dump(self))
  end

  def self.write_file_at(file, content)
    FileUtils.mkdir_p(File.dirname(file))
    File.open(file, 'w') do |file|
      file.write(content)
    end
  end

  def self.read_file_at(path)
    file = File.open(path, "rb")
    contents = file.read
    file.close
    contents
  end

  def api_endpoint
    endpoint = 'http://%s:%s/' % [self.masters[0].external_address, '8080']
  end

  def fectch_all_endpoints
    endpoint = '%s%s' % [self.api_endpoint, 'v1/endpoints']
    conn = Faraday.new
    response = conn.get endpoint, { }, { 'Accept' => 'application/json' }
    JSON.load(response.body)
  end

  def app_exists?(app_id)
    self.fectch_all_endpoints.select{|x| x['id'] == app_id }.length > 0
  end

  def fetch_app_endpoints(app_id)
    apps = self.fectch_all_endpoints.select{|x| x['id'] == app_id } 
    app = apps.length > 0 ? apps[0] : { 'instances' => [] }
    app['instances'].collect{|z|  
      server = self.server_from_internal_address(z['host'])
      { :server => server, :ports => z['ports'] }
    }
  end

  def fetch_app(app_id)
    app = self.fectch_all_endpoints.select{|x| x['id'] == app_id }[0]
    instances = app['instances'].collect{|z|  
      server = self.server_from_internal_address(z['host'])
      { :server => server, :ports => z['ports'] }
    }
    App.new(app_id, self)
  end

end
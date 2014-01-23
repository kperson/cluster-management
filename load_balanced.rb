require_relative 'app'
require 'digest/md5'
require 'zookeeper'

class LoadBalanced < App

  attr_accessor :git_repo, :version, :config_files, :type, :pre_deploy_scripts

  def initialize(app_id, git_repo, version, cluster, type, cpus = 1.0, ram = 512)
    super(app_id, cluster, cpus, ram)
    config_files = []
    self.type = type
    self.git_repo = git_repo
    self.version = version
    zk = ZK.new(self.cluster.masters.collect{|x| x.external_address + ":2181" }.join(",") + "/webapps")
    if !zk.exists?(self.git_key)
      begin
        zk.create(git_key)
        zk.create(version_key)
        zk.create(type_key)
        sleep(5)
        zk.set(self.version_key, version)
        zk.set(self.git_key, git_repo)
        zk.set(self.type_key, type)
      rescue ZK::Exceptions::NodeExists
      end
    end
    self.command = 'sudo /usr/local/bin/ruby /install/cluster-management/server-side/webapp.rb --port $PORT --id %s --clusterfile /install/cluster.yml' % [self.app_id]
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

  def app_dir
    "/" + self.app_hash
  end

  def add_config_file(source, destination)
    config_files << { :source  => source, :destination => destination }
  end

  def add_pre_deploy_script(source, destination, run_all_nodes = true)
    pre_deploy_scripts << { :source  => source, :destination => destination, :run_all_nodes => run_all_nodes }
  end

  def redeploy
  end

end
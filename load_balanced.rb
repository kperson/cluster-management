require_relative 'app'
require 'digest/md5'

class LoadBalanced < App

  attr_accessor :git_repo, :version, :config_files, :type, :pre_deploy_scripts

  def initialize(app_id, git_repo, version, cluster, type, cpus = 1.0, ram = 512)
    id = Digest::MD5.hexdigest(git_repo + "a123456f7890c").to_s
    super(app_id, cluster, cpus, ram)
    config_files = []
    self.type = type
    self.git_repo = git_repo
    self.version = version
  end

  def add_config_file(source, destination)
    config_files << { :source  => source, :destination => destination }
  end

  def add_pre_deploy_script(source, destination, run_all_nodes = true)
    pre_deploy_scripts << { :source  => source, :destination => destination, :run_all_nodes => run_all_nodes }
  end

  def reploy
  end

end
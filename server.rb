class Server

  attr_accessor :internal_address, :external_address, :is_master, :props

  def initialize(internal_address, external_address, is_master)
    self.internal_address = internal_address
    self.external_address = external_address
    self.is_master = is_master
    self.props = { }
  end

  def property(key, value)
    self.props[key] = value
    self
  end

end
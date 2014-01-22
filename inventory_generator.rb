require_relative 'file_helpers'

class InventoryGenerator

  attr_accessor :groups

  def initialize(groups)
    self.groups = groups
  end

  def self.generate_provision(cluster, output_file)
    InventoryGenerator.new({  :mesosmaster => cluster.masters, :mesosslaveonly => cluster.slave_only, :provisions => cluster.servers }).generate(output_file)
  end

  def generate(output_file)
    output = ""
    self.groups.each do |key, value| 
      output += "[%s]\n" %  [key]
      value.each do |server|
        props_output = []
        server.props.each do |p_key, p_value|
          props_output << "%s=%s" % [p_key, p_value]
        end
        props_output <<  "%s=%s" % ['internal_dns', server.internal_address]
        output += server.external_address + "   " +  props_output.join("   ") + "\n"

      end
      output += "\n"
    end
    FileHelpers.write_file_at(output_file, output)
  end
end

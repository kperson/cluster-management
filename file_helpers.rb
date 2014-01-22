require 'fileutils'

class FileHelpers

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

end
module ExtraInfo
  EXTRA_INFO_FILE_PATH = Rails.root.to_s + "/tmp/extra_info.json"
  @@extra_info_hash = nil

  def self.read_extra_info
    return @@extra_info_hash unless @@extra_info_hash.nil?
    return {} unless File.exist?(EXTRA_INFO_FILE_PATH)
    @@extra_info_hash = JSON.parse(File.read(EXTRA_INFO_FILE_PATH))
    return @@extra_info_hash
  end

  def self.update(hash = {})
    new_hash = read_extra_info.merge(hash)
    File.open(EXTRA_INFO_FILE_PATH, "w"){
      |f| f.write(JSON.pretty_generate(new_hash))
    }
    @@extra_info_hash = new_hash
    return new_hash
  end

  def self.delete(*keyes)
    new_hash = read_extra_info
    keyes.flatten.each do |key|
      new_hash.delete(key)
    end
  	File.open(EXTRA_INFO_FILE_PATH, "w"){
      |f| f.write(JSON.pretty_generate(new_hash))
    }
    @@extra_info_hash = new_hash
    return new_hash
  end
end
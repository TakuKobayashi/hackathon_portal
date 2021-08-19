module ItchIoOperation
  ITCH_IO_JAMS_URL = 'https://itch.io/jams'

  def self.import_events_from_keywords!(keywords:)
    self.imoport_gamejam_events!
  end

  def self.imoport_gamejam_events!; end
end

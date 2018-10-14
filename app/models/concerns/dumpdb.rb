module Dumpdb
  def to_dump_command(output_root_path:)
    environment = Rails.env
    configuration = ActiveRecord::Base.configurations[environment]
    database = Shellwords.escape(Regexp.escape(configuration['database'].to_s))
    username = Shellwords.escape(Regexp.escape(configuration['username'].to_s))
    password = Shellwords.escape(Regexp.escape(configuration['password'].to_s))

    table = self.table_name
    commands = []
    if password.present?
      commands << "MYSQL_PWD=#{password}"
    end
    commands << "mysqldump"
    commands << "-u"
    commands << username
    commands << "--skip-lock-tables"
    commands << "-t"
    commands << database
    commands << table
    commands << ">"
    commands << [output_root_path, "#{table}.sql"].join("/")
    return commands.join(" ")
  end

  def dump_table!(output_root_path:, is_export_log: true)
    command = to_dump_command(output_root_path: output_root_path)
    if is_export_log
      Dumpdb.record_log(command: command)
    end
    system(command)
    return [output_root_path, "#{self.table_name}.sql"].join("/")
  end

  def self.record_log(command:)
    logger = ActiveSupport::Logger.new("log/dumpdb_command.log")
    console = ActiveSupport::Logger.new(STDOUT)
    logger.extend ActiveSupport::Logger.broadcast(console)
    messages = [
      "Time:" + Time.current.to_s,
      "dump command:" + command
    ]
    message = messages.join("\n")
    message << "\n\n"
    logger.info(message)
  end
end
namespace :backup do
  task dump_and_upload_and_clear_data: :environment do
    backup_models = [
      Ai::AppearWord,
      Ai::HashtagTrigram,
      Ai::Hashtag,
      Ai::ResourceAttachment,
      Ai::ResourceHashtag,
      Ai::ResourceSentence,
      Ai::ResourceSummary,
      Ai::Trigram,
      Ai::TweetResource,
    ]
    BackupToGoogleServices.backup_and_upload_and_clear_data!(backup_models: backup_models)
  end

  task update_table_to_spreadsheet: :environment do
    backup_models = [Event]
    BackupToGoogleServices.backup_table_to_spreadsheet!(backup_models: backup_models)
  end

  task export_active_records_data: :environment do
    environment = Rails.env
    configuration = ActiveRecord::Base.configurations.configs_for.detect{|c| c.env_name == environment}
    configuration_hash = configuration.try(:configuration_hash) || {}
    host = Regexp.escape(configuration_hash[:host].to_s)
    database = Regexp.escape(configuration_hash[:database].to_s)
    username = Regexp.escape(configuration_hash[:username].to_s)
    password = Regexp.escape(configuration_hash[:password].to_s)
    unless Dir.exists?(Rails.root.join("db", "seeds"))
      FileUtils.mkdir(Rails.root.join("db", "seeds"))
    end
    # 動いているOSの判別
    host_os = RbConfig::CONFIG['host_os']
    puts host_os
    Rails.application.eager_load!
    model_classes = ActiveRecord::Base.descendants.select{|m| m.table_name.present? }.uniq{|m| m.table_name }
    model_classes.each do |model_class|
      export_table_directory_name = Rails.root.join("db", "seeds", model_class.table_name)
      export_full_dump_sql = Rails.root.join("db", "seeds", model_class.table_name + ".sql")
      mysqldump_commands = ["mysqldump", "-u", username, "-h", host]
      if password.present?
        mysqldump_commands << "-p#{password}"
      end
      mysqldump_commands += [database, model_class.table_name, "--no-create-info","-c","--order-by-primary", "--skip-extended-insert", "--skip-add-locks", "--skip-comments", "--compact", ">", export_full_dump_sql]
      system(mysqldump_commands.join(" "))
      if Dir.exists?(export_table_directory_name)
        FileUtils.remove_dir(export_table_directory_name)
      end
      Dir.mkdir(export_table_directory_name)
      # 動いているOSの判別
      case host_os
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        # windows
        system("split -l 10000 -d --additional-suffix=.sql #{export_full_dump_sql} #{export_table_directory_name}/")
      when /darwin|mac os/
        # macosx
        system("gsplit -l 10000 -d --additional-suffix=.sql #{export_full_dump_sql} #{export_table_directory_name}/")
      when /linux/
        # linux
        system("split -l 10000 -d --additional-suffix=.sql #{export_full_dump_sql} #{export_table_directory_name}/")
      when /solaris|bsd/
        # unix
        system("split -l 10000 -d --additional-suffix=.sql #{export_full_dump_sql} #{export_table_directory_name}/")
      else
        # unknown
        system("split -l 10000 -d --additional-suffix=.sql #{export_full_dump_sql} #{export_table_directory_name}/")
      end
      FileUtils.rm(export_full_dump_sql)
    end
  end

  task export_json_data: :environment do
    events = Event.select(:event_id, :type, :title, :url, :shortener_url, :started_at, :ended_at, :limit_number, :address, :place, :lat, :lon, :informed_from, :state).order(started_at: :desc).all
    unless Dir.exists?(Rails.root.join("db", "jsons"))
      FileUtils.mkdir(Rails.root.join("db", "jsons"))
    end
    export_json_path = Rails.root.join("db", "jsons", "events.json")
    File.write(export_json_path, events.to_json)
  end

  task cd_git_commit_and_push: :environment do
    git = Git.open(Rails.root.to_s)
    git.add(Rails.root.join("db", "seeds"))
    git.commit("update " + Time.current.strftime("%Y%m%d %H:%M:%S") + " crawled data")
    git.push(git.remote('master'))
  end
end

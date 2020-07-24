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
    configuration = ActiveRecord::Base.configurations[environment]
    host = Regexp.escape(configuration['host'].to_s)
    database = Regexp.escape(configuration['database'].to_s)
    username = Regexp.escape(configuration['username'].to_s)
    password = Regexp.escape(configuration['password'].to_s)
    unless Dir.exists?(Rails.root.join("db", "seeds"))
      FileUtils.mkdir(Rails.root.join("db", "seeds"))
    end
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
      system("split -l 10000 -d --additional-suffix=.sql #{export_full_dump_sql} #{export_table_directory_name}/")
      FileUtils.rm(export_full_dump_sql)
    end
  end

  task cd_git_commit_and_push: :environment do
    git = Git.open(Rails.root.to_s)
    git.add(Rails.root.join("db", "seeds"))
    git.commit("update " + Time.current.strftime("%Y%m%d %H:%M:%S") + " crawled data")
    git.push(git.remote('master'))
  end
end

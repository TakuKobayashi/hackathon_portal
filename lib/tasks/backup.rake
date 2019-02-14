namespace :backup do
  task dump_and_upload_and_clear_data: :environment do
    drive = BackupToGoogleServices.get_google_drive_service
    [
      Ai::AppearWord,
      Ai::HashtagTrigram,
      Ai::Hashtag,
      Ai::ResourceAttachment,
      Ai::ResourceHashtag,
      Ai::ResourceSentence,
      Ai::ResourceSummary,
      Ai::Trigram,
      Ai::TweetResource,
    ].each do |clazz|
      table_name = clazz.table_name
      sql_file_path = Dumpdb.dump_table!(
        table_name: table_name,
        output_root_path: Rails.root.join("tmp").to_s
      )
      s3 = Aws::S3::Client.new
      exist_files = drive.list_files({q: "name='#{table_name}.sql'"})
      File.open(sql_file_path, 'rb') do |sql_file|
        result = drive.create_file(upload_source: f)
        s3.put_object(bucket: "taptappun", body: sql_file, key: "backup/hackathon_portal/dbdump/#{table_name}.sql", acl: "public-read")
      end
      File.delete(sql_file_path)
    end
  end

  task upload_event_spreadsheet: :environment do
    backup_models = [Event, Scaling::UnityEvent]
    table_names = backup_models.map(&:table_name)
    BackupToGoogleServices.generate_sheet!(sheet_names: table_names)

    backup_models.each do |model_class|
      model_class.find_each do |event|
      # write spread sheet
      end
    end
  end
end
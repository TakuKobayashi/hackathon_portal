require 'google/apis/sheets_v4'
require 'google/apis/drive_v3'

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
      result = drive.create_file(
        {
          name: "#{table_name}.sql",
          parents: ["143QAunJyQZCDnu19U3jQOMvZWf2Jb_Q_"]
        },
        {
          upload_source: sql_file_path,
          content_type: 'application/octet-stream',
          fields: '*',
          supports_team_drives: true
        }
      )
      File.open(sql_file_path, 'rb') do |sql_file|
        s3.put_object(bucket: "taptappun", body: sql_file, key: "backup/hackathon_portal/dbdump/#{table_name}.sql", acl: "public-read")
      end
      File.delete(sql_file_path)
    end
  end

  task clear_and_restart_ai_tables: :environment do
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
      prev_auto_increment_id = clazz.last.try(:id).to_i + 1
      clazz.connection.execute("TRUNCATE TABLE #{clazz.table_name}")
      clazz.connection.execute("ALTER TABLE #{clazz.table_name} AUTO_INCREMENT=#{prev_auto_increment_id}")
    end
  end

  task upload_event_spreadsheet: :environment do
    backup_models = [Event, Scaling::UnityEvent]
    table_names = backup_models.map(&:table_name)
#    BackupToGoogleServices.generate_sheet!(sheet_names: table_names)
    backup_models.each do |model_class|
      row_count = model_class.count
      column_names = model_class.column_names
      start_row = 1
      start_column = 1
      end_row = start_row + row_count
      end_column = start_column + column_names.size - 1

      range = "'#{model_class.table_name}'!R#{start_row}C#{start_column}:R#{end_row}C#{end_column}"
      cell_rows = []
      cell_rows << column_names
      model_class.find_each do |event|
        cell_rows << (column_names).map{|column_name| event.send(column_name).to_s }
      end
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: cell_rows)
      p cell_rows
      p range
      updated = BackupToGoogleServices.get_google_sheet_service.update_spreadsheet_value("1bIEvJBml-Y-uiiVcNQzdKbbR9rSsb4ott-nQY4AucyQ", range, value_range, value_input_option: 'USER_ENTERED')
    end
  end
end
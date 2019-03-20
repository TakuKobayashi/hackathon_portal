require "google/apis/sheets_v4"
require "google/apis/drive_v3"
require "google/apis/blogger_v3"

module BackupToGoogleServices
  SPREADSHEET_ID = "1bIEvJBml-Y-uiiVcNQzdKbbR9rSsb4ott-nQY4AucyQ"
  BACKUP_ROOT_DIRECTORY_NAME = "backup"

  def self.get_google_sheet_service
    sheet_service = Google::Apis::SheetsV4::SheetsService.new
    sheet_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    return sheet_service
  end

  def self.get_google_drive_service
    drive_service = Google::Apis::DriveV3::DriveService.new
    drive_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    return drive_service
  end

  def self.backup_and_upload_and_clear_data!(backup_models: [])
    drive = self.get_google_drive_service
    backup_folder = drive.list_files({ q: "name='#{BACKUP_ROOT_DIRECTORY_NAME}' and mimeType='application/vnd.google-apps.folder'" }).files.first
    if backup_folder.blank?
      backup_folder = drive.create_file({
        name: BACKUP_ROOT_DIRECTORY_NAME,
        mime_type: "application/vnd.google-apps.folder",
      },
                                        {
        fields: "*",
        supports_team_drives: true,
      })
    end
    exists_table_name_folders = drive.list_files({ q: "mimeType='application/vnd.google-apps.folder' and parents in '#{backup_folder.id}'" }).files.index_by(&:name)
    backup_models.each do |clazz|
      table_name = clazz.table_name
      root_folder = exists_table_name_folders[table_name]
      if root_folder.blank?
        root_folder = drive.create_file({
          name: table_name,
          mime_type: "application/vnd.google-apps.folder",
          parents: [backup_folder.id],
        },
                                        {
          fields: "*",
          supports_team_drives: true,
        })
      end
      local_sql_file_path = Dumpdb.dump_table!(
        table_name: table_name,
        output_root_path: Rails.root.join("tmp").to_s,
      )
      #s3 = Aws::S3::Client.new
      sql_filename = "#{Time.current.strftime("%Y%m%d_%H%M%S")}_#{table_name}.sql"
      result = drive.create_file(
        {
          name: sql_filename,
          parents: [root_folder.id],
        },
        {
          upload_source: local_sql_file_path,
          content_type: "application/octet-stream",
          fields: "*",
          supports_team_drives: true,
        }
      )
      #      File.open(local_sql_file_path, 'rb') do |sql_file|
      #        s3.put_object(bucket: "taptappun", body: sql_file, key: "backup/hackathon_portal/dbdump/#{sql_filename}", acl: "public-read")
      #      end
      File.delete(local_sql_file_path)
      self.clear_and_restart_table!(clazz: clazz)
    end
  end

  def self.clear_and_restart_table!(clazz:)
    prev_auto_increment_id = clazz.last.try(:id).to_i + 1
    clazz.connection.execute("TRUNCATE TABLE #{clazz.table_name}")
    clazz.connection.execute("ALTER TABLE #{clazz.table_name} AUTO_INCREMENT=#{prev_auto_increment_id}")
  end

  def self.backup_table_to_spreadsheet!(backup_models: [])
    service = self.get_google_sheet_service
    target_spreadsheet = service.get_spreadsheet(SPREADSHEET_ID)
    backup_models.each do |model_class|
      row_count = model_class.count
      column_names = model_class.column_names - ["created_at", "updated_at", "location_image_binary"]
      start_row = 1
      start_column = 1
      end_row = start_row + row_count
      end_column = start_column + column_names.size - 1

      sheet_name = model_class.table_name
      if target_spreadsheet.sheets.all? { |sheet| sheet.properties.title != sheet_name }
        sheet_request_hash = {
          add_sheet: {
            properties: {
              title: sheet_name,
            },
          },
        }
        batch_update_request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new({ requests: [sheet_request_hash] })
        result = service.batch_update_spreadsheet(SPREADSHEET_ID, batch_update_request)
      end

      range = "'#{sheet_name}'!R#{start_row}C#{start_column}:R#{end_row}C#{end_column}"
      cell_rows = []
      cell_rows << column_names
      model_class.find_each do |event|
        cell_rows << (column_names).map { |column_name| event.send(column_name).to_s }
      end
      value_range = Google::Apis::SheetsV4::ValueRange.new(values: cell_rows)
      updated = service.update_spreadsheet_value(SPREADSHEET_ID, range, value_range, value_input_option: "USER_ENTERED")
    end
  end

  def self.get_google_blogger_service
    blogger_service = Google::Apis::BloggerV3::BloggerService.new
    blogger_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    return blogger_service
  end
end

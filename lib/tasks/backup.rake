require 'google/apis/sheets_v4'

SPREADSHEET_ID = "1bIEvJBml-Y-uiiVcNQzdKbbR9rSsb4ott-nQY4AucyQ"

namespace :backup do
  task dump_and_upload_and_clear_data: :environment do
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
      File.open(sql_file_path, 'rb') do |sql_file|
        s3.put_object(bucket: "taptappun", body: sql_file, key: "backup/hackathon_portal/dbdump/#{table_name}.sql", acl: "public-read")
      end
      File.delete(sql_file_path)
    end
  end

  task upload_event_spreadsheet: :environment do
    sheet_service = Google::Apis::SheetsV4::SheetsService.new
    sheet_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    target_spreadsheet = service.get_spreadsheet(SPREADSHEET_ID)

    sheet_id_titles = {}
    target_spreadsheet.sheets.each do |sheet|
      sheet_id_titles[sheet.properties.sheet_id] = sheet.properties.title
    end
    sheet_titles = sheet_id_titles.values

    backup_models = [Event]
    table_names = backup_models.map(&:table_name)
    table_names.reject!{|table_name| sheet_titles.any?{|title| title == table_name } }
    if table_names.present?
      max_sheet_id = sheet_id_titles.keys.max{|sheet_id| sheet_id.to_i }
      add_sheet_requests = table_names.map do |table_name|
        {
          add_sheet: {
            properties: {
              sheet_id: max_sheet_id + 1,
              title: table_name
            },
            fields: 'title'
          }
        }
      end
      sheet_service.batch_update_spreadsheet(SPREADSHEET_ID, {requests: add_sheet_requests}, {})
    end

    backup_models.each do |model_class|
      model_class.find_each do |event|
      # write spread sheet
      end
    end
  end
end
require 'google/apis/sheets_v4'

SPREADSHEET_ID = "1bIEvJBml-Y-uiiVcNQzdKbbR9rSsb4ott-nQY4AucyQ"

module BackupSpreadsheet
  def self.get_google_sheet_service
    sheet_service = Google::Apis::SheetsV4::SheetsService.new
    sheet_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", ""))
    return sheet_service
  end

  def self.generate_sheet!(sheet_names: [])
    service = self.get_google_sheet_service
    target_spreadsheet = service.get_spreadsheet(SPREADSHEET_ID)

    sheet_id_titles = {}
    target_spreadsheet.sheets.each do |sheet|
      sheet_id_titles[sheet.properties.sheet_id] = sheet.properties.title
    end
    sheet_titles = sheet_id_titles.values

    sheet_names.reject!{|sheet_name| sheet_titles.any?{|title| title == sheet_name } }
    if sheet_names.present?
      max_sheet_id = sheet_id_titles.keys.max{|sheet_id| sheet_id.to_i }
      add_sheet_requests = sheet_names.map do |sheet_name|
        {
          add_sheet: {
            properties: {
              sheet_id: max_sheet_id + 1,
              title: sheet_name
            },
            fields: 'title'
          }
        }
      end
      result = service.batch_update_spreadsheet(SPREADSHEET_ID, {requests: add_sheet_requests}, {})
    end
  end
end
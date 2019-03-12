require 'google/apis/sheets_v4'
require 'google/apis/drive_v3'

module BackupToGoogleServices
  SPREADSHEET_ID = "1bIEvJBml-Y-uiiVcNQzdKbbR9rSsb4ott-nQY4AucyQ"

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
end
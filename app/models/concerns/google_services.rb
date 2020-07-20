require 'google/apis/sheets_v4'
require 'google/apis/drive_v3'
require 'google/apis/blogger_v3'
require 'google/apis/calendar_v3'
require 'google/apis/script_v1'

module GoogleServices
  def self.get_sheet_service(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    sheet_service = Google::Apis::SheetsV4::SheetsService.new
    sheet_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: refresh_token)
    return sheet_service
  end

  def self.get_drive_service(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    drive_service = Google::Apis::DriveV3::DriveService.new
    drive_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: refresh_token)
    return drive_service
  end

  def self.get_blogger_service(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    blogger_service = Google::Apis::BloggerV3::BloggerService.new
    blogger_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: refresh_token)
    return blogger_service
  end

  def self.get_calender_service(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: refresh_token)
    return service
  end

  def self.get_script_service(refresh_token: ENV.fetch('GOOGLE_OAUTH_BOT_REFRESH_TOKEN', ''))
    script_service = Google::Apis::ScriptV1::ScriptService.new
    script_service.authorization = GoogleOauth2Client.oauth2_client(refresh_token: refresh_token)
    return script_service
  end
end

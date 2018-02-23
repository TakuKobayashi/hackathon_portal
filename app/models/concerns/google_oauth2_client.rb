module GoogleOauth2Client
  AUTH_URL = "https://accounts.google.com/o/oauth2/auth"
  TOKEN_URL = "https://accounts.google.com/o/oauth2/token"

  def self.record_access_token(authorization)
    ExtraInfo.update({"google_oauth" => {"access_token" => authorization.access_token, "expires_at" => authorization.expires_at.to_s}})
  end

  def self.oauth2_client
    google_oauth_config = ExtraInfo.read_extra_info["google_oauth"] || {}
    oauth_client = Signet::OAuth2::Client.new
    oauth_client.client_id = ENV.fetch("GOOGLE_OAUTH_CLIENT_ID", "")
    oauth_client.client_secret = ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET", "")
    oauth_client.access_token = google_oauth_config["access_token"]
    oauth_client.authorization_uri = AUTH_URL
    oauth_client.token_credential_uri = TOKEN_URL
    oauth_client.refresh_token = ENV.fetch("GOOGLE_OAUTH_BOT_REFRESH_TOKEN", "")
    return oauth_client
  end
end
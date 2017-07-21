require 'googleauth'

client_secret = Google::Auth::ClientId.from_file(Rails.root.to_s + "/client_secret.json")
# 自己入力部分
client_id     = client_secret.id
client_secret = client_secret.secret
redirect_uri  = "http://localhost"
scope         = "https://www.googleapis.com/auth/gmail.compose"

# 自動部分
oauth_url = "https://accounts.google.com/o/oauth2/auth?client_id=#{client_id}&redirect_uri=#{redirect_uri}&scope=#{scope}&response_type=code&approval_prompt=force&access_type=offline"
`open "#{oauth_url}"`

print "認証コード(アドレスバーの?code=以下の部分全て)を入力してエンター："
code = gets.chomp

puts `curl -d client_id=#{client_id} -d client_secret=#{client_secret} -d redirect_uri=#{redirect_uri} -d grant_type=authorization_code -d code=#{code} https://accounts.google.com/o/oauth2/token`
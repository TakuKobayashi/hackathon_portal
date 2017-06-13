#OmniAuth.config.full_host = "https://taptappun.net"

api_config = YAML.load(File.read("#{Rails.root.to_s}/config/apiconfig.yml"))
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, api_config["twitter"]["consumer_key"], api_config["twitter"]["consumer_secret"]
end
api_config = YAML.load(File.read("#{Rails.root.to_s}/config/apiconfig.yml"))
Geocoder.configure(
    :api_key => api_config["google"]["apikey"],
    :use_https => true
)
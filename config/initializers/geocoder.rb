Geocoder.configure(
  api_key: ENV.fetch("GOOGLE_API_KEY", ""),
  language: "ja",
  use_https: true,
)

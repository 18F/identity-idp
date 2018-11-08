Geocoder.configure(
  ip_lookup: :geoip2,
  geoip2: {
    file: Rails.root.join('data', 'GeoLite2-City_20181106', 'GeoLite2-City.mmdb'),
  }
)

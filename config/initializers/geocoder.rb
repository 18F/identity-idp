Geocoder.configure(
  ip_lookup: :geoip2,
  geoip2: {
    file: Rails.root.join('geo_data', 'GeoLite2-City.mmdb'),
  },
)

class IpGeocoder
  def initialize(ip)
    @ip = ip
  end

  def location
    return city_and_state if city && state

    country
  end

  private

  attr_reader :ip

  def city_and_state
    "#{city}, #{state]}"
  end

  def city
    geocoded_location&.city
  end

  def state
    geocoded_location&.state_code
  end

  def country
    geocoded_location&.country
  end

  def geocoded_location
    @geocoded_location ||= begin
      Geocoder.search(ip).first
    rescue => error
      Rails.logger.info "Geocode error: #{error.class.name}: #{error.message}"
    end
  end
end

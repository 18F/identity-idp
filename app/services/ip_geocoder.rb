class IpGeocoder
  def initialize(ip)
    @ip = ip
  end

  def location
    geocoded_location&.language = I18n.locale

    return city_and_state if both_city_and_state_present?
    return country if country.present?

    I18n.t('account.index.unknown_location')
  end

  private

  attr_reader :ip

  def city_and_state
    "#{city}, #{state}"
  end

  def both_city_and_state_present?
    city.present? && state.present?
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
    @geocoded_location ||= Geocoder.search(ip).first
  end
end

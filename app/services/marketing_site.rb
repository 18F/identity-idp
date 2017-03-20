class MarketingSite
  BASE_URL = URI('https://login.gov').freeze

  def self.base_url
    BASE_URL.to_s
  end

  def self.privacy_url
    URI.join(BASE_URL, '/policy').to_s
  end

  def self.contact_url
    URI.join(BASE_URL, '/contact').to_s
  end

  def self.help_url
    URI.join(BASE_URL, '/help').to_s
  end
end

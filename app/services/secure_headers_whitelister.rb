class SecureHeadersWhitelister
  def self.extract_domain(url)
    url.split('//')[1].split('/')[0]
  end
end

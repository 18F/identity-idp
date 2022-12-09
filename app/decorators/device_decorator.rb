DeviceDecorator = Struct.new(:device) do
  delegate :last_used_at, :id, to: :device

  def last_sign_in_location_and_ip
    I18n.t('account.index.sign_in_location_and_ip', location: last_location, ip: device.last_ip)
  end

  def last_location
    IpGeocoder.new(device.last_ip).location
  end

  def happened_at
    device.last_used_at.utc
  end

  def nice_name
    browser = BrowserCache.parse(device.user_agent)
    os = browser.platform_name
    os_version = browser.platform_version&.split('.')&.first
    os = "#{os} #{os_version}" if os_version

    I18n.t(
      'account.index.device',
      browser: "#{browser.name} #{browser.version}",
      os: os,
    )
  end
end

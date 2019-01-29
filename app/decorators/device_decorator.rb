DeviceDecorator = Struct.new(:device) do
  delegate :nice_name, :last_used_at, :id, to: :device

  def device_partial
    'accounts/device_item'
  end

  def last_sign_in_location_and_ip
    I18n.t('account.index.sign_in_location_and_ip', location: last_location, ip: device.last_ip)
  end

  def last_location
    IpGeocoder.new(device.last_ip).location
  end

  def happened_at
    device.last_used_at.utc
  end
end

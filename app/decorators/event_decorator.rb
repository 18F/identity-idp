EventDecorator = Struct.new(:event) do
  def event_partial
    'accounts/event_item'
  end

  def event_type
    I18n.t("event_types.#{event.event_type}")
  end

  def happened_at
    event.created_at.utc
  end

  def happened_at_in_words
    UtcTimePresenter.new(happened_at).to_s
  end

  def last_sign_in_location_and_ip
    return '' unless event&.respond_to?(:ip)
    I18n.t('account.index.sign_in_location_and_ip', location: last_location, ip: event.ip)
  end

  def last_location
    return '' unless event&.respond_to?(:ip)
    IpGeocoder.new(event.ip).location
  end
end

class Event < ActiveRecord::Base
  belongs_to :user

  enum event_type: {
    account_created: 1,
    phone_confirmed: 2,
    password_changed: 3,
    phone_changed: 4,
    email_changed: 5,
    authenticator_enabled: 6,
    authenticator_disabled: 7
  }

  validates :event_type, presence: true
  validates :location, presence: true

  def self.pretty_user_agent(user_agent)
    return if user_agent.nil?
    parsed_user_agent = UserAgent.parse(user_agent)
    return if parsed_user_agent.browser.nil? || parsed_user_agent.platform.nil?
    parsed_user_agent.browser + '/' + parsed_user_agent.platform
  end

  def self.create_from_request(user, event_type, request)
    create!(
      user_id: user.id,
      event_type: event_type,
      location: Event.ip_to_location_string(request.remote_ip),
      user_agent: Event.pretty_user_agent(request.user_agent)
    )
  end

  def self.event_type_to_s(event_type)
    raise 'Invalid event type' unless event_types.keys.include?(event_type)
    I18n.t('event_types.' + event_type.to_s)
  end

  def self.ip_to_location_string(ip_address)
    loc = Geocoder.search(ip_address, ip_address: true).first
    return ip_address if loc.country == 'Reserved'
    [loc.city, loc.state_code, loc.country_code].join(', ')
  end
end

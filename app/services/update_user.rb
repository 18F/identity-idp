class UpdateUser
  def initialize(user:, attributes:)
    @user = user
    @attributes = attributes
  end

  def call
    result = user.update!(
      attributes.except(
        :phone_id, :phone, :phone_confirmed_at,
        :otp_make_default_number
      ),
    )
    manage_phone_configuration
    result
  end

  private

  attr_reader :user, :attributes

  def manage_phone_configuration
    if attributes[:phone_id].present?
      update_phone_configuration unless phone_configuration.nil?
    else
      create_phone_configuration
    end
  end

  def update_phone_configuration
    phone_configuration.update!(phone_attributes)
  end

  def create_phone_configuration
    return if phone_attributes[:phone].blank? || duplicate_phone?
    phone_configuration = MfaContext.new(user).phone_configurations.create(phone_attributes)
    event = PushNotification::RecoveryInformationChangedEvent.new(user: user)
    PushNotification::HttpPush.deliver(event)
    phone_configuration
  end

  def duplicate_phone?
    MfaContext.new(user).phone_configurations.map(&:phone).index(phone_attributes[:phone])
  end

  def phone_attributes
    @phone_attributes ||= {
      phone: attributes[:phone],
      confirmed_at: attributes[:phone_confirmed_at],
      delivery_preference: attribute(:otp_delivery_preference),
      made_default_at: made_default_at_date,
    }.delete_if { |_, value| value.nil? }
  end

  def made_default_at_date
    if attributes[:otp_make_default_number].to_s == 'true'
      Time.zone.now
    else
      current_made_default_at
    end
  end

  def current_made_default_at
    phone_configuration.made_default_at if attributes[:phone_id].present?
  end

  def phone_configuration
    MfaContext.new(user).phone_configuration(attributes[:phone_id])
  end

  # This returns the named attribute if it's included in the changes, even if
  # it's nil. Otherwise, it pulls the information from the user object. This
  # lets us create a phone_configuration row with all required information even
  # if we're only updating the otp_delivery_preference in the user model. Once
  # we no longer write data to the user model, we can remove this and simplify
  # some of this code.
  def attribute(name)
    if attributes.include?(name)
      attributes[name]
    else
      user.send(name)
    end
  end
end

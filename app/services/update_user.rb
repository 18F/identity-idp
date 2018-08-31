class UpdateUser
  def initialize(user:, attributes:)
    @user = user
    @attributes = attributes
  end

  def call
    result = user.update!(attributes.except(:phone, :phone_confirmed_at))
    manage_phone_configuration
    result
  end

  private

  attr_reader :user, :attributes

  def manage_phone_configuration
    if user.phone_configuration.present?
      update_phone_configuration
    else
      create_phone_configuration
    end
  end

  def update_phone_configuration
    user.phone_configuration.update!(phone_attributes)
  end

  def create_phone_configuration
    return if phone_attributes[:phone].blank?
    user.create_phone_configuration(phone_attributes)
  end

  def phone_attributes
    @phone_attributes ||= {
      phone: attributes[:phone],
      confirmed_at: attributes[:phone_confirmed_at],
      delivery_preference: attribute(:otp_delivery_preference),
    }.delete_if { |_, value| value.nil? }
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

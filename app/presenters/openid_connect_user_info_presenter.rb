class OpenidConnectUserInfoPresenter
  include Rails.application.routes.url_helpers

  attr_reader :identity

  def initialize(identity)
    @identity = identity
  end

  def user_info
    info = {
      sub: identity.uuid,
      iss: root_url,
      email: identity.user.email,
      email_verified: true,
    }.merge(loa3_attributes)

    OpenidConnectAttributeScoper.new(identity.scope).filter(info)
  end

  private

  def loa3_attributes
    phone = loa3_data.phone

    {
      given_name: loa3_data.first_name,
      family_name: loa3_data.last_name,
      middle_name: loa3_data.middle_name,
      birthdate: loa3_data.dob,
      address: address,
      phone: phone,
      phone_verified: phone.present? ? true : nil,
    }
  end

  def address
    return nil if loa3_data.address1.blank?

    {
      formatted: formatted_address,
      street_address: street_address,
      locality: loa3_data.city,
      region: loa3_data.state,
      postal_code: loa3_data.zipcode,
    }
  end

  def formatted_address
    [
      street_address,
      "#{loa3_data.city}, #{loa3_data.state} #{loa3_data.zipcode}",
    ].compact.join("\n")
  end

  def street_address
    [loa3_data.address1, loa3_data.address2].compact.join(' ')
  end

  def loa3_data
    @loa3_data ||= begin
      if loa3_session?
        Pii::SessionStore.new(identity.session_uuid).load
      else
        Pii::Attributes.new_from_hash({})
      end
    end
  end

  def loa3_session?
    identity.ial == 3
  end

  def session_store
    config = Rails.application.config
    config.session_store.new({}, config.session_options)
  end
end

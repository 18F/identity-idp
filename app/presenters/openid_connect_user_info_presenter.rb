class OpenidConnectUserInfoPresenter
  include Rails.application.routes.url_helpers

  attr_reader :identity

  def initialize(identity)
    @identity = identity
  end

  def user_info
    info = {
      sub: uuid_from_sp_identity(identity),
      iss: root_url,
      email: identity.user.email,
      email_verified: true,
    }.merge(loa3_attributes)

    OpenidConnectAttributeScoper.new(identity.scope).filter(info)
  end

  private

  def uuid_from_sp_identity(identity)
    AgencyIdentityLinker.new(identity).link_identity.uuid
  end

  # rubocop:disable Metrics/AbcSize
  def loa3_attributes
    phone = stringify_attr(loa3_data.phone)

    {
      given_name: stringify_attr(loa3_data.first_name),
      family_name: stringify_attr(loa3_data.last_name),
      birthdate: stringify_attr(loa3_data.dob),
      social_security_number: stringify_attr(loa3_data.ssn),
      address: address,
      phone: phone,
      phone_verified: phone.present? ? true : nil,
    }
  end
  # rubocop:enable Metrics/AbcSize

  def address
    return nil if loa3_data.address1.blank?

    {
      formatted: formatted_address,
      street_address: street_address,
      locality: stringify_attr(loa3_data.city),
      region: stringify_attr(loa3_data.state),
      postal_code: stringify_attr(loa3_data.zipcode),
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

  def stringify_attr(attribute)
    attribute.to_s.presence
  end

  def loa3_data
    @loa3_data ||= begin
      if loa3_session?
        Pii::SessionStore.new(identity.rails_session_id).load
      else
        Pii::Attributes.new_from_hash({})
      end
    end
  end

  def loa3_session?
    identity.ial == 3
  end
end

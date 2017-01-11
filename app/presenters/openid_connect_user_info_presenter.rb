class OpenidConnectUserInfoPresenter
  include Rails.application.routes.url_helpers

  attr_reader :identity

  def initialize(identity)
    @identity = identity
  end

  def user_info
    user = identity.user

    {
      sub: identity.uuid,
      iss: root_url,
      email: user.email,
      email_verified: true
    }.merge(loa3_attributes)
  end

  private

  # TODO: only return loa1 attributes for loa1 sessions
  def loa3_attributes
    {
      given_name: loa3_data.first_name,
      family_name: loa3_data.last_name,
      middle_name: loa3_data.middle_name,
      birthdate: loa3_data.dob,
      postal_code: loa3_data.zipcode
      # address formatting?
    }
  end

  def loa3_data
    @loa3_data ||= begin
      session = session_store.send(:load_session_from_redis, identity.session_uuid) || {}
      Pii::Attributes.new_from_json(session.dig('warden.user.user.session', :decrypted_pii))
    end
  end

  def session_store
    config = Rails.application.config
    config.session_store.new({}, config.session_options)
  end
end

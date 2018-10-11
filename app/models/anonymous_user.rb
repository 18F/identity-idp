class AnonymousUser
  EMPTY_EMAIL_ADDRESS = OpenStruct.new(
    email: nil,
    confirmed?: false,
    confirmed_at: nil
  ).freeze

  def uuid
    'anonymous-uuid'
  end

  def second_factor_locked_at
    nil
  end

  def phone_configurations
    []
  end

  def phone
    nil
  end

  def webauthn_configurations
    []
  end

  def x509_dn_uuid; end

  def otp_secret_key; end

  def email; end

  def email_address
    EMPTY_EMAIL_ADDRESS
  end

  def confirmed_at
    Time.zone.now
  end
end

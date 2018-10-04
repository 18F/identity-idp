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

  def email; end

  def email_address
    EMPTY_EMAIL_ADDRESS
  end
end

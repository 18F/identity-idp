class ReactivateAccountSession
  SESSION_KEY = :reactivate_account

  attr_reader :user

  def initialize(user:, user_session:)
    @user = user
    @session = user_session

    session[SESSION_KEY] ||= generate_session
  end

  def clear
    session.delete(SESSION_KEY)
  end

  def start
    reactivate_account_session[:active] = true
  end

  def started?
    reactivate_account_session[:active]
  end

  def suspend
    session[SESSION_KEY] = generate_session
  end

  # Stores PII as a string in the session
  # @param [Pii::Attributes]
  def store_decrypted_pii(pii)
    reactivate_account_session[:validated_personal_key] = true
    Pii::Cacher.new(user, session).save_decrypted_pii(pii, user.password_reset_profile.id)
    nil
  end

  def validated_personal_key?
    reactivate_account_session[:validated_personal_key]
  end

  # Parses string into PII struct
  # @return [Pii::Attributes, nil]
  def decrypted_pii
    return unless validated_personal_key?
    Pii::Cacher.new(user, session).fetch(user.password_reset_profile.id)
  end

  private

  attr_reader :session

  def generate_session
    {
      active: false,
      validated_personal_key: false,
    }
  end

  def reactivate_account_session
    session[SESSION_KEY]
  end
end

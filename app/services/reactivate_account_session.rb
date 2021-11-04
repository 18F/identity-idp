class ReactivateAccountSession
  SESSION_KEY = :reactivate_account

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
    reactivate_account_session[:personal_key] = true
    reactivate_account_session[:pii] = pii.to_json
  end

  def personal_key?
    reactivate_account_session[:personal_key]
  end

  # Parses string into PII struct
  # @return [Pii::Attributes, nil]
  def decrypted_pii
    json_str = reactivate_account_session[:pii]
    Pii::Attributes.new_from_json(json_str) if json_str
  end

  private

  attr_reader :session

  def generate_session
    {
      active: false,
      personal_key: false,
      pii: nil,
      x509: nil,
    }
  end

  def reactivate_account_session
    session[SESSION_KEY]
  end
end

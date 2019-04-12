class PersonalKeyForNewUserPolicy
  def initialize(user:, session:)
    @user = user
    @session = session
  end

  # For new users who visit the site directly or via an LOA1 request,
  # we show them their personal key after they set up 2FA for the first
  # time during account creation. These users only see the personal key
  # once during account creation. LOA3 users, on the other hand, need to
  # confirm their personal key after verifying their identity because
  # the key is used to encrypt their PII. Rather than making LOA3 users
  # confirm personal keys twice, once after 2FA setup, and once after
  # proofing, we only show it to them once after proofing.
  def show_personal_key_after_initial_2fa_setup?
    !FeatureManagement.personal_key_assignment_disabled? &&
      user_does_not_have_a_personal_key? &&
      user_did_not_make_an_loa3_request?
  end

  private

  attr_reader :user, :session

  def user_does_not_have_a_personal_key?
    user.encrypted_recovery_code_digest.blank?
  end

  def user_did_not_make_an_loa3_request?
    sp_session.empty? || sp_session[:loa3] == false
  end

  def sp_session
    session.fetch(:sp, {})
  end
end

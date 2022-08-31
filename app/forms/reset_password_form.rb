class ResetPasswordForm
  include ActiveModel::Model
  include FormPasswordValidator

  attr_accessor :reset_password_token

  validate :valid_token

  def initialize(user)
    @user = user
    self.reset_password_token = @user.reset_password_token
  end

  def submit(params)
    self.password = params[:password]

    @success = valid?

    handle_valid_password if success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :success

  def valid_token
    if !user.persisted?
      # If the user is not saved in the database, that means looking them up by
      # their token failed
      errors.add(:reset_password_token, 'invalid_token', type: :invalid_token)
    elsif !user.reset_password_period_valid? || invalid_account?
      errors.add(:reset_password_token, 'token_expired', type: :token_expired)
    end
  end

  def handle_valid_password
    update_user
    mark_profile_inactive
  end

  def update_user
    attributes = { password: password }

    ActiveRecord::Base.transaction do
      unless user.confirmed?
        now = Time.zone.now
        user.email_addresses.take.update(confirmed_at: now)
        attributes[:confirmed_at] = now
      end

      UpdateUser.new(user: user, attributes: attributes).call
    end
  end

  def mark_profile_inactive
    profile = user.active_profile
    return if profile.blank?

    @profile_deactivated = true
    profile&.deactivate(:password_reset)
    Funnel::DocAuth::ResetSteps.call(user.id)
    user.proofing_component&.destroy
  end

  # It is possible for an account that is resetting their password to be "invalid".
  # If an unconfirmed account (which must have one unconfirmed email address) resets their
  # password and a different account then adds and confirms that same email address,
  # the initial account is no longer able to confirm their email address and is effectively invalid.
  #
  # They may still have a valid forgot password link for the initial account, which would normally
  # mark their email as confirmed when they set a new password, but we do not want to allow it
  # because we only allow an email address to be confirmed on one account.
  def invalid_account?
    !user.confirmed? &&
      EmailAddress.confirmed.exists?(
        email_fingerprint: user.email_addresses.map(&:email_fingerprint),
      )
  end

  def extra_analytics_attributes
    {
      user_id: user.uuid,
      profile_deactivated: (@profile_deactivated == true),
    }
  end
end

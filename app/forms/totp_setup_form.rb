# frozen_string_literal: true

class TotpSetupForm
  include ActiveModel::Model

  validate :name_is_unique
  validates :name, presence: true

  attr_reader :name_taken

  def initialize(user, secret, code, name)
    @user = user
    @secret = secret
    @code = code
    @name = name
    @auth_app_config = nil
  end

  def submit
    @success = valid? && valid_totp_code?

    process_valid_submission if success

    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :code, :secret, :success, :name

  def valid_totp_code?
    # The two_factor_authentication gem raises an error if the secret is nil.
    return false if secret.nil?
    new_timestamp = Db::AuthAppConfiguration.confirm(secret, code)
    if new_timestamp
      create_auth_app(user, secret, new_timestamp, name) if new_timestamp
    end
    new_timestamp.present?
  end

  def process_valid_submission
    user.save!
  end

  def mfa_context
    user
  end

  def extra_analytics_attributes
    {
      totp_secret_present: secret.present?,
      multi_factor_auth_method: 'totp',
      auth_app_configuration_id: @auth_app_config&.id,
      enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
    }
  end

  def mfa_user
    MfaContext.new(user)
  end

  def create_auth_app(user, secret, new_timestamp, name)
    # Release the suspended row only now that the code has been verified, so a
    # failed attempt never destroys the credential being replaced.
    suspended_name_holder.call

    @auth_app_config = Db::AuthAppConfiguration.create(user, secret, new_timestamp, name)
  end

  def name_is_unique
    # A name held only by this user's own suspended configuration is not a
    # conflict: it is released when the replacement is actually enrolled.
    return if suspended_name_holder.releasable?
    return unless AuthAppConfiguration.exists?(user_id: @user.id, name: @name)

    errors.add :name, I18n.t('errors.piv_cac_setup.unique_name'), type: :unique_name
    @name_taken = true
  end

  def suspended_name_holder
    @suspended_name_holder ||= AccountRecovery::ReleaseSuspendedCredential.new(
      user: user,
      configuration: AuthAppConfiguration.find_by(user_id: @user&.id, name: @name),
    )
  end
end

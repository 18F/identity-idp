class TotpSetupForm
  include ActiveModel::Model

  validate :name_is_unique

  attr_reader :name_taken

  def initialize(user, secret, code, name = Time.zone.now.to_s)
    @user = user
    @secret = secret
    @code = code.strip
    @name = name.strip
  end

  def submit
    @success = valid? && valid_totp_code?

    process_valid_submission if success

    FormResponse.new(success: success, errors: {}, extra: extra_analytics_attributes)
  end

  private

  attr_reader :user, :code, :secret, :success, :name

  def valid_totp_code?
    # The two_factor_authentication gem raises an error if the secret is nil.
    return false if secret.nil?
    is_added = user.confirm_totp_secret(secret, code)
    Db::AuthAppConfiguration::Create.call(user, secret, name) if is_added
    is_added
  end

  def process_valid_submission
    user.save!
  end

  def extra_analytics_attributes
    {
      totp_secret_present: secret.present?,
      multi_factor_auth_method: 'totp',
    }
  end

  def name_is_unique
    return unless AuthAppConfiguration.exists?(user_id: @user.id, name: @name)
    errors.add :name, I18n.t('errors.piv_cac_setup.unique_name')
    @name_taken = true
  end
end

class BackupCodeSetupForm
  include ActiveModel::Model

  validates :user, presence: true

  def initialize(user)
    @user = user
  end

  def submit
    FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
  end

  private

  attr_reader :success
  attr_accessor :user

  def mfa_user
    @mfa_user ||= MfaContext.new(user)
  end

  def extra_analytics_attributes
    {
      mfa_method_counts: mfa_user.enabled_two_factor_configuration_counts_hash,
      enabled_mfa_methods_count: mfa_user.enabled_mfa_methods_count,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
    }
  end
end

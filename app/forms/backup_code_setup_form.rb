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

  def extra_analytics_attributes
    {
      mfa_method_counts: MfaContext.new(user).enabled_two_factor_configuration_counts_hash,
      pii_like_keypaths: [[:mfa_method_counts, :phone]],
    }
  end
end

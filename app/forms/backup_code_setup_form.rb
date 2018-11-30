class BackupCodeSetupForm
  include ActiveModel::Model

  validates :user, presence: true

  def initialize(user, user_session)
    @user = user
    @success = false
    @codes = []
  end

  def submit
    success = valid?
    if success
      create_backup_codes_configuration
      create_user_event
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  # this gives us a hook to override the domain embedded in the attestation test object
  def self.domain_name
    Figaro.env.domain_name
  end

  private

  attr_reader :success
  attr_accessor :user

  def create_backup_codes_configuration
    # BackupCodeConfiguration.create
  end

  def create_user_event
    # Event.create(user_id: user.id, event_type: :backup_codes_added)
  end

  def extra_analytics_attributes
    { mfa_method_counts: MfaContext.new(user).enabled_two_factor_configuration_counts_hash }
  end
end

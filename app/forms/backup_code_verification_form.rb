# frozen_string_literal: true

class BackupCodeVerificationForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper
  include DOTIW::Methods

  validate :validate_rate_limited
  validate :validate_and_consume_backup_code!

  attr_reader :user, :backup_code, :request

  def initialize(user:, request:)
    @user = user
    @request = request
  end

  def submit(params)
    @backup_code = params[:backup_code]

    rate_limiter.increment!

    FormResponse.new(
      success: valid?,
      errors:,
      extra: extra_analytics_attributes,
    )
  end

  private

  def validate_rate_limited
    return if !rate_limiter.limited?
    errors.add(
      :backup_code,
      :rate_limited,
      message: t(
        'errors.messages.phone_confirmation_limited',
        timeout: distance_of_time_in_words(Time.zone.now, rate_limiter.expires_at),
      ),
    )
  end

  def validate_and_consume_backup_code!
    return if rate_limiter.limited? || valid_backup_code?
    errors.add(:backup_code, :invalid, message: t('two_factor_authentication.invalid_backup_code'))
  end

  def valid_backup_code?
    valid_backup_code_config_created_at.present?
  end

  def valid_backup_code_config_created_at
    return @valid_backup_code_config_created_at if defined?(@valid_backup_code_config_created_at)
    @valid_backup_code_config_created_at = BackupCodeGenerator.new(user)
      .if_valid_consume_code_return_config_created_at(backup_code)
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      rate_limit_type: :backup_code_user_id_per_ip,
      target: [user.id, request.ip].join('-'),
    )
  end

  def extra_analytics_attributes
    { multi_factor_auth_method_created_at: }
  end

  def multi_factor_auth_method_created_at
    return nil if !valid?
    valid_backup_code_config_created_at.strftime('%s%L')
  end
end

# frozen_string_literal: true

class BackupCodeVerificationForm
  include ActiveModel::Model
  include ActionView::Helpers::TranslationHelper

  validate :validate_and_consume_backup_code!

  def initialize(user)
    @user = user
    @backup_code = ''
  end

  def submit(params)
    @backup_code = params[:backup_code]
    FormResponse.new(
      success: valid?,
      errors:,
      extra: extra_analytics_attributes,
      serialize_error_details_only: true,
    )
  end

  attr_reader :user, :backup_code

  def validate_and_consume_backup_code!
    return if valid_backup_code?
    errors.add(:backup_code, :invalid, message: t('two_factor_authentication.invalid_backup_code'))
  end

  def valid_backup_code?
    valid_backup_code_config_created_at.present?
  end

  def valid_backup_code_config_created_at
    return @valid_backup_code_config_created_at if defined?(@valid_backup_code_config_created_at)
    @valid_backup_code_config_created_at = BackupCodeGenerator.new(user).
      if_valid_consume_code_return_config_created_at(backup_code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method_created_at: valid_backup_code_config_created_at&.strftime('%s%L'),
    }
  end
end

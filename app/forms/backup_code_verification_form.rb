# frozen_string_literal: true

class BackupCodeVerificationForm
  include ActiveModel::Model

  def initialize(user)
    @user = user
    @backup_code = ''
  end

  def submit(params)
    @backup_code = params[:backup_code]
    FormResponse.new(
      success: valid_backup_code?,
      extra: extra_analytics_attributes,
    )
  end

  attr_reader :user, :backup_code

  def valid_backup_code?
    valid_backup_code_config_created_at.present?
  end

  def valid_backup_code_config_created_at
    return @valid_backup_code_config_created_at if defined?(@valid_backup_code_config_created_at)
    @valid_backup_code_config_created_at = BackupCodeGenerator.new(@user).
      if_valid_consume_code_return_config_created_at(backup_code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method_created_at: valid_backup_code_config_created_at&.strftime('%s%L'),
    }
  end
end

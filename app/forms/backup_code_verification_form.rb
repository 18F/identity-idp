class BackupCodeVerificationForm
  include ActiveModel::Model

  def initialize(user)
    @user = user
    @backup_code = ''
  end

  def submit(params)
    @backup_code = params[:backup_code]
    @ga_client_id = params[:ga_client_id]
    FormResponse.new(
      success: valid_backup_code?,
      errors: {},
      extra: extra_analytics_attributes,
    )
  end

  attr_reader :user, :backup_code, :ga_client_id

  def valid_backup_code?
    BackupCodeGenerator.new(@user).verify(backup_code)
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'backup_code',
      ga_client_id: ga_client_id,
    }
  end
end

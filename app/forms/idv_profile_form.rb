class IdvProfileForm
  attr_reader :user, :errors, :params

  def initialize(user)
    @user = user
    @errors = []
  end

  def submit(params)
    @params = params
    error_required_params if required_params_blank?
    error_duplicate_ssn if ssn_taken?
    @errors.blank?
  end

  private

  def required_params
    [:first_name, :last_name, :dob, :ssn, :address1, :city, :state, :zipcode]
  end

  def required_params_blank?
    required_params.any? { |param| !params.key?(param) || params[param].blank? }
  end

  def error_required_params
    required_params.each do |param|
      next if params[param].present?
      field_name = I18n.t("idv.form.#{param}")
      err_msg = "#{field_name} is required"
      @errors << err_msg
    end
  end

  def error_duplicate_ssn
    @errors << I18n.t('idv.errors.duplicate_ssn')
  end

  def ssn_taken?
    ssn = params[:ssn]
    return false unless ssn.present?
    Profile.where.not(user: user.id).where(ssn: ssn).any?
  end
end

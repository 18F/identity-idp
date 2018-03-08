class KbaSecurityForm
  include ActiveModel::Model

  attr_accessor :token, :selected_answer, :user, :answer

  def initialize(token:)
    @token = token
    @answer = ''
    cpr = @token.blank? ? nil : ChangePhoneRequest.find_by(granted_token: @token)
    @user = cpr.user if cpr&.granted_token && !cpr&.change_phone_link_expired?
    @selected_answer = select_default_answer
  end

  def submit(params)
    return no_answer_selected unless params
    @token = params[:token]
    @answer = params[:answer]
    validate_submission
  end

  private

  def validate_submission
    if @answer == '-1'
      no_answer_selected
    else
      answer_selected
    end
  end

  def no_answer_selected
    errors = { answer: I18n.t('kba_security.select_answer_error') }
    form_response(false, errors)
  end

  def answer_selected
    cpr = ChangePhoneRequest.find_by(granted_token: @token) if @token.present?
    @user = cpr.user if cpr
    form_response(valid_form?, {})
  end

  def form_response(success, errors)
    FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
  end

  def select_default_answer
    if @user && Figaro.env.reset_device_show_security_answer == 'true'
      ResetDevice.new(@user).correct_security_answer
    else
      -1
    end
  end

  def valid_form?
    valid? && token_valid? && answer_correct?
  end

  def token_valid?
    cpr = ChangePhoneRequest.find_by(granted_token: @token)
    return false unless cpr
    @user = cpr.user
    @token == cpr.granted_token && !cpr.change_phone_link_expired?
  end

  def answer_correct?
    answer = @answer.to_i
    return false unless answer >= 0
    ResetDevice.new(@user).correct_security_answer == answer
  end

  def extra_analytics_attributes
    {
      answer: @answer,
    }
  end
end

class KbaSecurityController < ApplicationController
  def show
    @kba_security_form = kba_security_form
    redirect_to root_url unless @kba_security_form.user
  end

  def update
    form = kba_security_form
    result = form.submit(params[:kba_security_form])
    return if handle_errors(result)
    analytics.track_event(Analytics::RESET_DEVICE_SECURITY_ANSWER, result.to_h)
    process_result(form.user, result)
    redirect_to root_url
  end

  private

  def process_result(user, result)
    if result.success?
      handle_success(user, kba_security_form)
    else
      handle_failure(user, kba_security_form)
    end
  end

  def handle_errors(result)
    errors = result.errors
    error_message = errors[:answer]
    if error_message
      flash[:error] = error_message
      redirect_to change_phone_url(token: params[:kba_security_form][:token])
      return true
    end
    false
  end

  def handle_success(user, kba_security_form)
    answer = kba_security_form.answer
    ResetDevice.new(user).submit_correct_answer(answer)
    flash[:success] = t('kba_security.success')
  end

  def handle_failure(user, kba_security_form)
    answer = kba_security_form.answer
    ResetDevice.new(user).submit_wrong_answer(answer)
    flash[:error] = t('kba_security.wrong_answer')
  end

  def kba_security_form
    KbaSecurityForm.new(token: params[:token])
  end
end

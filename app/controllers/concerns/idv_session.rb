module IdvSession
  extend ActiveSupport::Concern

  if Figaro.env.proofing_vendors
    Figaro.env.proofing_vendors.split(/\W+/).each do |vendor|
      vendor_path = "#{Rails.root}/vendor/#{vendor}/lib"
      $LOAD_PATH.unshift vendor_path
    end
  end

  protected

  def idv_question_number
    idv_session[:question_number] ||= 0
  end

  def idv_resolution
    idv_session[:resolution]
  end

  def proofing_session_started?
    idv_resolution.present? &&
      idv_applicant.present? &&
      idv_resolution.success &&
      idv_resolution.questions &&
      idv_resolution.questions.any?
  end

  def set_idv_vendor(vendor)
    idv_session[:vendor] = vendor
  end

  def set_idv_applicant(applicant)
    idv_session[:applicant] = applicant
  end

  def set_idv_pii(applicant)
    idv_session[:pii_id] = PII.create_from_proofer_applicant(applicant, current_user).id
  end

  def set_idv_resolution(resolution)
    idv_session[:resolution] = resolution
  end

  def set_idv_question_number(n)
    idv_session[:question_number] = n
  end

  def idv_vendor
    idv_session[:vendor]
  end

  def idv_applicant
    idv_session[:applicant]
  end

  def pii_id
    idv_session[:pii_id]
  end

  def clear_idv_session
    idv_session.delete(:vendor)
    idv_session.delete(:applicant)
    idv_session.delete(:pii_id)
    idv_session.delete(:resolution)
    idv_session.delete(:question_number)
  end

  def idv_session
    user_session[:idv] ||= {}
  end
end

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

  def idv_questions
    idv_resolution.questions
  end

  def proofing_session_started?
    idv_resolution.present? &&
      idv_applicant.present? &&
      idv_resolution.success?
  end

  def idv_vendor=(vendor)
    idv_session[:vendor] = vendor
  end

  def idv_applicant=(applicant)
    idv_session[:applicant] = applicant
  end

  def idv_profile_from_applicant(applicant)
    idv_session[:profile_id] = Profile.create_from_proofer_applicant(applicant, current_user).id
  end

  def idv_resolution=(resolution)
    idv_session[:resolution] = resolution
  end

  def idv_question_number=(num)
    idv_session[:question_number] = num
  end

  def idv_params=(idv_params)
    idv_session[:params] = idv_params
  end

  def idv_vendor
    idv_session[:vendor]
  end

  def idv_applicant
    idv_session[:applicant]
  end

  def idv_profile_id
    idv_session[:profile_id]
  end

  def idv_params
    idv_session[:params] ||= {}
  end

  def idv_profile
    @_profile ||= Profile.find(idv_profile_id)
  end

  def clear_idv_session
    user_session.delete(:idv)
  end

  def idv_session
    user_session[:idv] ||= {}
  end

  def complete_idv_profile
    idv_profile.verified_at = Time.zone.now
    idv_profile.vendor = idv_vendor
    idv_profile.activate
  end
end

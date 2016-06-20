module IdvSession
  extend ActiveSupport::Concern

  if ENV['PROOFING_VENDORS']
    ENV.fetch('PROOFING_VENDORS', '').split(/\W+/).each do |vendor|
      vendor_path = "#{Rails.root}/vendor/#{vendor}/lib"
      $LOAD_PATH.unshift vendor_path
    end 
  end 

  protected

  def idv_question_number
    session[:idv_question_number] ||= 0
  end 

  def idv_resolution
    session[:idv_resolution]
  end 

  def proofing_session_started?
    session.key?(:idv_resolution) &&
      session[:idv_resolution].present? &&
      session.key?(:idv_applicant) &&
      session[:idv_applicant].present?
  end

  def set_idv_vendor(vendor)
    session[:idv_vendor] = vendor
  end

  def set_idv_applicant(applicant)
    session[:idv_applicant] = applicant
  end

  def set_idv_resolution(resolution)
    session[:idv_resolution] = resolution
  end

  def set_idv_question_number(n)
    session[:idv_question_number] = n
  end

  def idv_vendor
    session[:idv_vendor]
  end

  def idv_applicant
    session[:idv_applicant]
  end

  def clear_idv_session
    session.delete(:idv_vendor)
    session.delete(:idv_applicant)
    session.delete(:idv_resolution)
    session.delete(:idv_question_number)
  end
end

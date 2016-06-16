module IdvSession
  extend ActiveSupport::Concern

  protected

  def question_number
    session[:question_number] ||= 0
  end 

  def resolution
    session[:resolution]
  end 

  def proofing_session_started?
    session.key?(:resolution) && session[:resolution].present?
  end

  def idv_vendor
    session[:idv_vendor]
  end

  def clear_idv_session
    session.delete(:idv_vendor)
    session.delete(:resolution)
    session.delete(:question_number)
  end
end

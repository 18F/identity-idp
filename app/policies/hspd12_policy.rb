class Hspd12Policy
  def initialize(session:, user:)
    @session = session
    @user = user
  end

  def piv_cac_setup_required?
    piv_cac_required? && !piv_cac_enabled?
  end

  def piv_cac_required?
    return if session.blank? || Figaro.env.allow_piv_cac_required != 'true'
    sp_session = session.fetch(:sp, {})
    return if sp_session.blank?
    sp_session[:hspd12_piv_cac_requested]
  end

  private

  def piv_cac_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
  end

  attr_reader :session, :user
end

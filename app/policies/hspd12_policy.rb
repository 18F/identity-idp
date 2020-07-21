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
    sp_session[:requested_attributes]&.include?('x509_presented')
  end

  private

  def piv_cac_enabled?
    TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
  end

  attr_reader :session, :user
end

module SpRedirect
  extend ActiveSupport::Concern

  def redirect_to_sp
    return if redirect_url.blank?
    redirect_to(redirect_url)
  end

  def redirect_url
    last_identity_url if current_user.last_identity.present?
  end

  def last_identity_url
    sp = ServiceProvider.new(current_user.last_identity.service_provider)
    sp.sp_initiated_login_url || sp.acs_url
  end
end

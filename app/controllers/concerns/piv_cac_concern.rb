module PivCacConcern
  extend ActiveSupport::Concern

  def create_piv_cac_nonce
    user_session[:piv_cac_nonce] = SecureRandom.base64(20)
  end

  def piv_cac_nonce
    user_session[:piv_cac_nonce]
  end

  def clear_piv_cac_nonce
    user_session[:piv_cac_nonce] = nil
  end
end

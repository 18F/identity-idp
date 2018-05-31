module PivCacConcern
  extend ActiveSupport::Concern

  def create_piv_cac_nonce
    user_session[:piv_cac_nonce] = SecureRandom.base64(20)
  end

  def piv_cac_nonce
    user_session[:piv_cac_nonce]
  end

  def clear_piv_cac_nonce
    user_session.delete(:piv_cac_nonce)
  end

  def save_piv_cac_information(data)
    user_session[:decrypted_x509] = data.to_json
  end

  def clear_piv_cac_information
    user_session.delete(:decrypted_x509)
  end
end

module PivCacConcern
  extend ActiveSupport::Concern

  def create_piv_cac_nonce
    piv_session[:piv_cac_nonce] = SecureRandom.base64(20)
  end

  def piv_cac_nonce
    piv_session[:piv_cac_nonce]
  end

  def clear_piv_cac_nonce
    piv_session.delete(:piv_cac_nonce)
  end

  def save_piv_cac_information(data)
    piv_session[:decrypted_x509] = data.to_json
  end

  def clear_piv_cac_information
    piv_session.delete(:decrypted_x509)
  end

  def piv_session
    user_session || session
  end
end

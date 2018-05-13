class UserPivCacVerificationForm
  include ActiveModel::Model

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :error_type, :nonce, :user

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_token?

    FormResponse.new(success: success, errors: {})
  end

  private

  def valid_token?
    user_has_piv_cac &&
      token_decoded &&
      token_has_correct_nonce &&
      not_error_token &&
      x509_cert_matches
  end

  def x509_cert_matches
    if user.confirm_piv_cac?(x509_dn_uuid)
      true
    else
      self.error_type = 'user.piv_cac_mismatch'
      false
    end
  end

  def token_decoded
    @data = PivCacService.decode_token(token)
    true
  end

  def not_error_token
    possible_error = @data['error']
    if possible_error
      self.error_type = possible_error
      false
    else
      self.x509_dn_uuid = @data['uuid']
      self.x509_dn = @data['dn']
      true
    end
  end

  def token_has_correct_nonce
    if @data['nonce'] == nonce
      true
    else
      self.error_type = 'token.invalid'
      false
    end
  end

  def user_has_piv_cac
    if user.piv_cac_enabled?
      true
    else
      self.error_type = 'user.no_piv_cac_associated'
      false
    end
  end
end

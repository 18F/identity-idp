class UserPivCacVerificationForm
  include ActiveModel::Model

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :error_type, :nonce, :user

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_token?

    FormResponse.new(
      success: success,
      errors: {},
      extra: extra_analytics_attributes(params),
      )
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
    if MfaContext.new(user).piv_cac_configuration.mfa_confirmed?(x509_dn_uuid)
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
      self.x509_dn = @data['subject']
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
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled?
      true
    else
      self.error_type = 'user.no_piv_cac_associated'
      false
    end
  end

  def extra_analytics_attributes(params)
    {
      multi_factor_auth_method: 'piv_cac',
      ga_client_id: params[:ga_client_id],
    }
  end
end

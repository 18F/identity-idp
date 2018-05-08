class UserPivCacSetupForm
  include ActiveModel::Model

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :user, :nonce, :error_type

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true

  def submit
    success = valid? && valid_token?

    FormResponse.new(success: success && process_valid_submission, errors: {})
  end

  private

  def process_valid_submission
    user.x509_dn_uuid = x509_dn_uuid
    user.save!
    Event.create(user_id: user.id, event_type: :piv_cac_enabled)
    true
  rescue PG::UniqueViolation
    self.error_type = 'piv_cac.already_associated'
    false
  end

  def valid_token?
    user_has_no_piv_cac &&
      token_decoded &&
      token_has_correct_nonce &&
      not_error_token &&
      piv_cac_not_already_associated
  end

  def token_decoded
    @data = PivCacService.decode_token(@token)
    true
  end

  def not_error_token
    possible_error = @data['error']
    if possible_error
      self.error_type = possible_error
      false
    else
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

  def piv_cac_not_already_associated
    self.x509_dn_uuid = @data['uuid']
    self.x509_dn = @data['dn']
    if User.find_by(x509_dn_uuid: x509_dn_uuid)
      self.error_type = 'piv_cac.already_associated'
      false
    else
      true
    end
  end

  def user_has_no_piv_cac
    if user.piv_cac_enabled?
      self.error_type = 'user.piv_cac_associated'
      false
    else
      true
    end
  end
end

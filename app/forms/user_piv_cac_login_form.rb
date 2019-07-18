class UserPivCacLoginForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :token, :error_type, :nonce, :user

  validates :token, presence: true
  validates :nonce, presence: true

  def submit
    success = valid? && valid_submission?

    FormResponse.new(success: success, errors: {})
  end

  private

  def valid_submission?
    valid_token? &&
      user_found
  end

  def user_found
    maybe_user = User.find_by(x509_dn_uuid: x509_dn_uuid)
    if maybe_user.present?
      self.user = maybe_user
      true
    else
      self.error_type = 'user.not_found'
      false
    end
  end
end

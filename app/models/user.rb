class User < ActiveRecord::Base
  include NonNullUuid

  after_validation :set_default_role, if: :new_record?

  devise :confirmable, :database_authenticatable, :recoverable, :registerable,
         :timeoutable, :trackable, :two_factor_authenticatable, :omniauthable,
         omniauth_providers: [:saml]

  enum role: { user: 0, tech: 1, admin: 2 }

  has_one_time_password

  has_many :authorizations, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :profiles, dependent: :destroy

  def set_default_role
    self.role ||= :user
  end

  def need_two_factor_authentication?(request)
    two_factor_enabled? && !third_party_authenticated?(request)
  end

  def third_party_authenticated?(request)
    request.env.key?('omniauth.auth') ? true : false
  end

  def two_factor_enabled?
    mobile.present?
  end

  def send_two_factor_authentication_code(_code)
    UserOtpSender.new(self).send_otp
  end

  def confirmation_period_expired?
    confirmation_sent_at && confirmation_sent_at.utc <= self.class.confirm_within.ago
  end

  def send_reset_confirmation
    update(reset_requested_at: Time.current, confirmed_at: nil)
    send_confirmation_instructions
  end

  def first_identity
    active_identities[0] unless active_identities.empty?
  end

  def last_identity
    active_identities[-1] unless active_identities.empty?
  end

  def last_quizzed_identity
    identities.order(updated_at: :desc).detect(&:quiz_started)
  end

  def active_identities
    identities.where(
      'last_authenticated_at IS NOT ?',
      nil
    ).order(
      last_authenticated_at: :asc
    )
  end

  def multiple_identities?
    active_identities.size > 1
  end

  def active_profile
    profiles.where(active: true).first
  end

  # To send emails asynchronously via ActiveJob.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end
end

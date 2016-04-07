class Authorization < ActiveRecord::Base
  belongs_to :user
  validates :user_id, :uid, :provider, presence: true
  validates :uid, uniqueness: { scope: :provider }

  before_save :perform_post_authorization_hooks

  def self.from_omniauth(auth_hash, existing_user = nil)
    if find_from_hash(auth_hash).present?
      auth = find_from_hash(auth_hash)
    else
      auth = create_from_hash(auth_hash, existing_user)
    end
    auth.update_user_role(auth_hash) if auth
    auth
  end

  def self.find_from_hash(auth_hash)
    auth = find_by_provider_and_uid(auth_hash.provider, auth_hash.extra.raw_info['cisUUID'])
    auth.update_authorized_at if auth
    auth
  end

  def self.create_from_hash(auth_hash, current_user = nil)
    user = current_user || find_or_create_user(auth_hash)

    create!(
      user: user,
      uid: auth_hash.extra.raw_info['UUID'],
      provider: auth_hash.provider,
      authorized_at: Time.zone.now
    )
  end

  def update_authorized_at
    update(authorized_at: Time.zone.now)
  end

  def self.find_or_create_user(auth_hash)
    # Look up existing users based on email only.
    user ||= User.find_or_create_by(email: auth_hash.extra.raw_info['emailAddress']) do |u|
      u.confirm_2fa!
      u.update!(account_type: :self, confirmed_at: Time.zone.now)
    end
    user
  end

  def update_user_uuid
    # Update UUID to match ENT ICAM
    # https://github.com/18F/save-ferris/issues/608#issuecomment-74936464
    user.update!(uuid: uid)
  end

  def update_user_role(auth_hash)
    groups = auth_hash.extra.raw_info.multi('groups') || auth_hash.extra.raw_info['groups']

    # TODO: clean this up and combine with Policy
    #       centralize authorization method
    user.role = :tech if groups.to_s.downcase.include? OmniauthCallbackPolicy::AUTHORIZED_TECH_SUPPORT_SAML_GROUP.downcase
    user.role = :admin if groups.to_s.downcase.include? OmniauthCallbackPolicy::AUTHORIZED_ADMIN_SAML_GROUP.downcase
    user.save!
  end

  def perform_post_authorization_hooks
    update_user_uuid if user.uuid != uid
  end
end

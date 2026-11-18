# frozen_string_literal: true

class UserPivCacSetupForm
  include ActiveModel::Model
  include PivCacFormHelpers

  attr_accessor :x509_dn_uuid, :x509_dn, :x509_issuer, :token, :user, :nonce, :error_type, :name,
                :key_id, :piv_cac_required
  attr_reader :name_taken

  validates :token, presence: true
  validates :nonce, presence: true
  validates :user, presence: true
  validates :name, presence: true
  validate :name_is_unique

  def submit
    success = valid? && valid_submission?

    FormResponse.new(
      success: success && process_valid_submission,
      errors:,
      extra: extra_analytics_attributes,
    )
  end

  private

  def process_valid_submission
    release_suspended_credentials

    user.piv_cac_configurations.create!(
      x509_dn_uuid: x509_dn_uuid,
      name: @name,
      x509_issuer: x509_issuer,
    )
    true
  rescue PG::UniqueViolation
    self.error_type = 'piv_cac.already_associated'
    false
  end

  def valid_submission?
    valid_token? && piv_cac_not_already_associated
  end

  def piv_cac_not_already_associated
    self.x509_dn_uuid = @data['uuid']
    self.x509_dn = @data['subject']
    self.x509_issuer = @data['issuer']

    # The user's own suspended card is not a conflict: it is released when the
    # replacement is actually enrolled.
    return true if suspended_card_holder.releasable?
    return true if !PivCacConfiguration.exists?(x509_dn_uuid: x509_dn_uuid)

    self.error_type = 'piv_cac.already_associated'
    errors.add(
      :piv_cac, I18n.t('headings.piv_cac_setup.already_associated'),
      type: :already_associated
    )
    false
  end

  def extra_analytics_attributes
    {
      multi_factor_auth_method: 'piv_cac',
      key_id: key_id,
    }
  end

  def name_is_unique
    return if suspended_name_holder.releasable?
    return unless PivCacConfiguration.exists?(user_id: @user.id, name: @name)

    errors.add :name, I18n.t('errors.piv_cac_setup.unique_name'), type: :unique_name
    @name_taken = true
  end

  # A card or name held only by this user's own suspended configuration is
  # released so the same credential can be re-enrolled during recovery. Only
  # done once enrollment is certain, so a failed attempt never destroys the
  # credential being replaced.
  def release_suspended_credentials
    [suspended_card_holder, suspended_name_holder]
      .select(&:releasable?)
      .uniq { |releaser| releaser.configuration.id }
      .each(&:call)
  end

  def suspended_card_holder
    @suspended_card_holder ||= AccountRecovery::ReleaseSuspendedCredential.new(
      user: user,
      configuration: PivCacConfiguration.find_by(x509_dn_uuid: x509_dn_uuid),
    )
  end

  def suspended_name_holder
    @suspended_name_holder ||= AccountRecovery::ReleaseSuspendedCredential.new(
      user: user,
      configuration: PivCacConfiguration.find_by(user_id: @user&.id, name: @name),
    )
  end
end

^^^
app/forms/gpo_verify_form.rb:85:1: E: Lint/Syntax: unexpected token tRSHFT
(Using Ruby 2.7 parser; configure using TargetRubyVersion parameter, under AllCops)
>>>>>>> origin/main
^^

1 file inspected, 3 offenses detected
====================
class GpoVerifyForm
  include ActiveModel::Model

  validates :otp, presence: true
  validate :validate_otp
  validate :validate_otp_not_expired
  validate :validate_pending_profile

  attr_accessor :otp, :pii, :pii_attributes
  attr_reader :user

  def initialize(user:, pii:, otp: nil)
    @user = user
    @pii = pii
    @otp = otp
  end

  def submit
    result = valid?
    if result
      if pending_in_person_enrollment?
        UspsInPersonProofing::EnrollmentHelper.new.save_in_person_enrollment(
          user,
          user.pending_profile,
          pii,
        )
        user.pending_profile&.deactivate(:in_person_verification_pending)
      else
        activate_profile
      end
    else
      reset_sensitive_fields
    end
    FormResponse.new(
      success: result,
      errors: errors,
      extra: {
        pii_like_keypaths: [[:errors, :otp], [:error_details, :otp]],
        pending_in_person_enrollment: pending_in_person_enrollment?,
      },
    )
  end

  protected

  def pending_profile
    @pending_profile ||= user.pending_profile
  end

  def gpo_confirmation_code
    return if otp.blank? || pending_profile.blank?

    pending_profile.gpo_confirmation_codes.first_with_otp(otp)
  end

  def validate_otp_not_expired
    return unless gpo_confirmation_code.present? && gpo_confirmation_code.expired?

    errors.add :otp, :gpo_otp_expired, type: :gpo_otp_expired
  end

  def validate_pending_profile
    errors.add :base, :no_pending_profile, type: :no_pending_profile unless pending_profile
  end

  def validate_otp
    return if otp.blank? || valid_otp?
    errors.add :otp, :confirmation_code_incorrect, type: :confirmation_code_incorrect
  end

  def valid_otp?
    otp.present? && gpo_confirmation_code.present?
  end

  def reset_sensitive_fields
    self.otp = nil
  end

  def pending_in_person_enrollment?
    return false unless IdentityConfig.store.in_person_proofing_enabled
    ProofingComponent.find_by(user: user)&.document_check == Idp::Constants::Vendors::USPS
  end

  def activate_profile
    user.pending_profile&.activate
  end
end

module PhoneConfirmable
  extend ActiveSupport::Concern

  included do
    before_update :postpone_mobile_change_until_confirmation, if: :postpone_mobile_change?
  end

  def initialize(*args, &block)
    @bypass_mobile_confirmation_postpone = false
    @mobile_reconfirmation_required = false
    super
  end

  def mobile_confirm
    pending_any_mobile_confirmation do
      saved =
        if unconfirmed_mobile.present?
          save_new_mobile
        else
          save
        end

      saved
    end
  end

  def save_new_mobile
    skip_mobile_reconfirmation
    self.mobile = unconfirmed_mobile
    self.unconfirmed_mobile = nil
    self.mobile_confirmed_at = Time.zone.now
    save
  end

  def mobile_confirmed?
    mobile_confirmed_at.present?
  end

  def pending_mobile_reconfirmation?
    unconfirmed_mobile.present?
  end

  def skip_mobile_reconfirmation
    @bypass_mobile_confirmation_postpone = true
  end

  protected

  # Checks whether the record requires any mobile confirmation.
  def pending_any_mobile_confirmation
    if !mobile_confirmed? || pending_mobile_reconfirmation?
      yield
    else
      errors.add(:mobile, :already_confirmed)
      false
    end
  end

  def postpone_mobile_change_until_confirmation
    @mobile_reconfirmation_required = true
    self.unconfirmed_mobile = mobile
    self.mobile = mobile_was
  end

  def postpone_mobile_change?
    postpone = mobile_changed? && !@bypass_mobile_confirmation_postpone && mobile.present?
    @bypass_mobile_confirmation_postpone = false
    postpone
  end
end

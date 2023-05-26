module FormDobValidator
  extend ActiveSupport::Concern
  include ActionView::Helpers::TranslationHelper

  included do
    include ActiveModel::Validations::Callbacks
    validate :validate_dob
  end

  private

  def validate_dob
    return unless dob.present?
    unless meet_min_age_req(dob)
      errors.add(:dob, message: dob_min_age_error, type: :dob_min_age_error)
    end
  end

  # @param [String|ActiveSupport::TimeWithZone] dob: string or ActiveSupport::TimeWithZone
  # @return [Boolean] false unless it meets the required minimal age, including invalid input value and types
  def meet_min_age_req(dob)
    return false if dob.nil?
    return false unless dob.is_a?(String) || dob.is_a?(ActiveSupport::TimeWithZone)
    begin
      dob_date = dob.is_a?(String) ? DateParser.parse_legacy(dob.strip) : dob
      today = Time.zone.today
      age = today.year - dob_date.year - ((today.month > dob_date.month ||
        (today.month == dob_date.month && today.day >= dob_date.day)) ? 0 : 1)
      age >= IdentityConfig.store.idv_min_age_years
    rescue
      false
    end
  end

  def dob_min_age_error
    I18n.t('doc_auth.errors.pii.birth_date_min_age')
  end
end

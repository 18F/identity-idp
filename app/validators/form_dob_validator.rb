module FormDobValidator
  extend ActiveSupport::Concern
  include ActionView::Helpers::TranslationHelper

  included do
    validate :validate_dob
  end

  private

  def validate_dob
    return unless dob.present?
    unless meet_min_age_req?(dob)
      errors.add(:dob, message: dob_min_age_error, type: :dob_min_age_error)
    end
  end

  private

  # @param [String|Date|ActionController::Parameters] dob
  # @return [Boolean] false unless it meets the required minimal age,
  #  including invalid input value and types
  def meet_min_age_req?(dob)
    return false if dob.nil?
    unless dob.is_a?(String) || dob.is_a?(ActionController::Parameters) ||
           dob.is_a?(Date)
      return false
    end
    begin
      dob_date =
        if dob.is_a?(ActionController::Parameters)
          param_to_date(dob)
        else
          dob
        end
      dob_date = DateParser.parse_legacy(dob_date)
      today = Time.zone.today
      age = today.year - dob_date.year - ((today.month > dob_date.month ||
        (today.month == dob_date.month && today.day >= dob_date.day)) ? 0 : 1)
      age >= IdentityConfig.store.idv_min_age_years
    rescue
      false
    end
  end

  def dob_min_age_error
    I18n.t(
      'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
      app_name: APP_NAME,
    )
  end

  #
  # @param [ActionController::Parameters] param
  # @return [Date]
  # It's caller's responsibility to ensure the param contains required entries
  def param_to_date(param)
    h = param.to_hash.with_indifferent_access
    Date.new(h[:year].to_i, h[:month].to_i, h[:day].to_i)
  end
end

module FormDobValidator
  extend ActiveSupport::Concern
  include ActionView::Helpers::TranslationHelper

  included do
    include ActiveModel::Validations::Callbacks
    private attr_accessor :dob_original

    # using rails 7 built-in Comparison validator
    validates_comparison_of :dob, less_than_or_equal_to: ->(_rec) {
      Time.zone.today - IdentityConfig.store.idv_min_age_years.years
    }, message: I18n.t(
      'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
      app_name: APP_NAME,
    )

    before_validation do
      # save original dob, convert it to Date
      self.dob_original = self.dob
      self.dob = val_to_date(self.dob_original)
    rescue
      self.dob = nil
    end

    after_validation do
      # restore original dob
      self.dob = self.dob_original
      self.dob_original = nil
    end
  end

  private

  #
  # @param [ActionController::Parameters|String|Date] param
  # @return [Date]
  # It's caller's responsibility to ensure the param contains required entries
  def val_to_date(param)
    return param if param.is_a?(Date)
    return DateParser.parse_legacy(param) if param.is_a?(String)
    h = param.to_hash.with_indifferent_access
    Date.new(h[:year].to_i, h[:month].to_i, h[:day].to_i)
  end
end

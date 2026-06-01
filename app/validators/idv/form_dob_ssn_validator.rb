# frozen_string_literal: true

module Idv
  module FormDobSsnValidator
    extend ActiveSupport::Concern
    include FormSsnFormatValidator

    included do
      # rubocop:disable Layout/LineLength
      validates_with UspsInPersonProofing::DateValidator,
                     attributes: [:dob], less_than_or_equal_to: ->(_rec) {
                       Time.zone.today - IdentityConfig.store.idv_min_age_years.years
                     },
                     message: ->(_, _) do
                       I18n.t(
                         'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
                         app_name: APP_NAME,
                       )
                     end
      # rubocop:enable Layout/LineLength
    end
  end
end

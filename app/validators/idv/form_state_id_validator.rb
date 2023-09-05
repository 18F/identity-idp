module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    included do
      validates :first_name,
                :last_name,
                :dob,
                :state_id_jurisdiction,
                :state_id_number,
                presence: true

      # rubocop:disable Style/MultilineIfModifier
      validates :identity_doc_address1,
                :identity_doc_city,
                presence: true if IdentityConfig.store.in_person_capture_secondary_id_enabled
      # rubocop:enable Style/MultilineIfModifier

      validates_with UspsInPersonProofing::TransliterableValidator,
                     fields: [:first_name, :last_name, :identity_doc_city],
                     reject_chars: /[^A-Za-z\-' ]/,
                     message: ->(invalid_chars) do
                       I18n.t(
                         'in_person_proofing.form.state_id.errors.unsupported_chars',
                         char_list: invalid_chars.join(', '),
                       )
                     end

      validates_with UspsInPersonProofing::TransliterableValidator,
                     fields: [:identity_doc_address1, :identity_doc_address2],
                     reject_chars: /[^A-Za-z0-9\-' .\/#]/,
                     message: ->(invalid_chars) do
                       I18n.t(
                         'in_person_proofing.form.state_id.errors.unsupported_chars',
                         char_list: invalid_chars.join(', '),
                       )
                     end
      # rubocop:disable Layout/LineLength
      validates_with UspsInPersonProofing::DateValidator,
                     attributes: [:dob], less_than_or_equal_to: ->(_rec) {
                       Time.zone.today - IdentityConfig.store.idv_min_age_years.years
                     },
                     message: I18n.t(
                       'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
                       app_name: APP_NAME,
                     )
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable Metrics/BlockLength
  end
end

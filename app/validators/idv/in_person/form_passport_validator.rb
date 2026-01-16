# frozen_string_literal: true

module Idv::InPerson::FormPassportValidator
  extend ActiveSupport::Concern

  # rubocop:disable Metrics/BlockLength
  included do
    validates :passport_surname,
              :passport_first_name,
              :passport_dob,
              :passport_number,
              :passport_expiration,
              presence: true

    validates :passport_surname, length: { maximum: 255 }
    validates :passport_first_name, length: { maximum: 255 }
    # rubocop:disable Layout/LineLength
    validates_format_of :passport_number,
                        with: /\A[a-zA-Z0-9]{9}\z/,
                        message: ->(_, _) {
                          I18n.t('in_person_proofing.form.passport.errors.passport_number.pattern_mismatch')
                        },
                        allow_blank: false
    # rubocop:enable Layout/LineLength

    validates_with UspsInPersonProofing::TransliterableValidator,
                   fields: [:passport_surname, :passport_first_name],
                   reject_chars: /[^A-Za-z\-' ]/,
                   message: ->(invalid_chars) do
                     I18n.t(
                       'in_person_proofing.form.state_id.errors.unsupported_chars',
                       char_list: invalid_chars.join(', '),
                     )
                   end

    # rubocop:disable Layout/LineLength
    validates_with UspsInPersonProofing::DateValidator,
                   attributes: [:passport_dob], less_than_or_equal_to: ->(_rec) {
                     Time.zone.today - IdentityConfig.store.idv_min_age_years.years
                   },
                   message: ->(_, _) do
                     I18n.t(
                       'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
                       app_name: APP_NAME,
                     )
                   end
    # rubocop:enable Layout/LineLength

    # rubocop:disable Layout/LineLength
    validates_with UspsInPersonProofing::DateValidator,
                   attributes: [:passport_expiration], greater_than_or_equal_to: ->(_rec) {
                     Time.zone.today
                   },
                   message: ->(_, _) do
                     I18n.t(
                       'in_person_proofing.form.passport.memorable_date.errors.expiration_date.expired',
                     )
                   end
    # rubocop:enable Layout/LineLength
  end
  # rubocop:enable Metrics/BlockLength
end

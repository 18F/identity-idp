# frozen_string_literal: true

module Idv
  module FormStateIdValidator
    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    included do
      validates :first_name,
                :last_name,
                :dob,
                :identity_doc_address1,
                :identity_doc_city,
                :state_id_jurisdiction,
                :state_id_number,
                :same_address_as_id,
                presence: true

      validates :id_expiration, presence: true, unless: :skip_expiration_date_validation?

      validates :id_expiration_option,
                inclusion: { in: Idv::StateIdForm::EXPIRATION_OPTIONS },
                if: :expiration_edge_cases_enabled?

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
                     message: ->(_, _) do
                       I18n.t(
                         'in_person_proofing.form.state_id.memorable_date.errors.date_of_birth.range_min_age',
                         app_name: APP_NAME,
                       )
                     end
      # rubocop:enable Layout/LineLength
      # rubocop:disable Layout/LineLength
      validates_with UspsInPersonProofing::DateValidator,
                     attributes: [:id_expiration], greater_than_or_equal_to: ->(_rec) {
                       Time.zone.today + 2.days
                     },
                     unless: :skip_expiration_date_validation?,
                     message: ->(_, _) do
                       I18n.t(
                         'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expired',
                         app_name: APP_NAME,
                       )
                     end
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable Metrics/BlockLength

    private

    def expiration_edge_cases_enabled?
      IdentityConfig.store.in_person_proofing_expiration_edge_cases_enabled
    end

    # Skip presence/date validation of id_expiration when the user selected a
    # non-date option (MIL/INDEF/No date) or entered a literal placeholder date.
    def skip_expiration_date_validation?
      return false unless expiration_edge_cases_enabled?

      expiration_option_sentinel? || placeholder_expiration?
    end

    def expiration_option_sentinel?
      Idv::StateIdForm::EXPIRATION_SENTINELS.include?(id_expiration_option)
    end

    def placeholder_expiration?
      Idv::StateIdForm::PLACEHOLDER_EXPIRATION_DATES.include?(normalized_id_expiration)
    end

    # id_expiration may be a { month:, day:, year: } hash (form input) or a string.
    # Coerces to a YYYY-MM-DD string for comparison against the literal
    # placeholders, tolerating both string and integer parts.
    def normalized_id_expiration
      return nil if id_expiration.blank?
      return id_expiration if id_expiration.is_a?(String)

      year = id_expiration[:year].to_s
      month = id_expiration[:month].to_s.rjust(2, '0')
      day = id_expiration[:day].to_s.rjust(2, '0')
      "#{year}-#{month}-#{day}"
    end
  end
end

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
                :asserted_id_type,
                presence: true

      # A boolean; `presence: true` would reject a legitimate `false`, so validate
      # that an explicit answer (true or false) was provided.
      validates :ipp_current_address_matches_id,
                inclusion: { in: [true, false] }

      validates :id_expiration, presence: true, unless: :skip_expiration_date_validation?

      validates :id_expiration_option,
                inclusion: { in: Idv::StateIdForm::EXPIRATION_OPTIONS },
                allow_blank: true,
                if: :expiration_edge_cases_enabled?

      validates_with Idv::TransliterableValidator,
                     fields: [:first_name, :last_name, :identity_doc_city],
                     reject_chars: /[^A-Za-z\-' ]/,
                     message: ->(invalid_chars) do
                       I18n.t(
                         'in_person_proofing.form.state_id.errors.unsupported_chars',
                         char_list: invalid_chars.join(', '),
                       )
                     end

      validates_with Idv::TransliterableValidator,
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
                         min_age: IdentityConfig.store.idv_min_age_years,
                       )
                     end
      # rubocop:enable Layout/LineLength
      # rubocop:disable Layout/LineLength
      validates_with UspsInPersonProofing::DateValidator,
                     attributes: [:id_expiration], greater_than_or_equal_to: ->(_rec) {
                       Time.zone.today + 7.days
                     },
                     unless: :skip_expiration_date_validation?,
                     message: ->(_, data) do
                       if data[:value].is_a?(Date) && data[:value] > Time.zone.today
                         I18n.t(
                           'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expiring_soon',
                         )
                       else
                         I18n.t(
                           'in_person_proofing.form.state_id.memorable_date.errors.expiration_date.expired',
                           app_name: APP_NAME,
                         )
                       end
                     end
      # rubocop:enable Layout/LineLength
    end
    # rubocop:enable Metrics/BlockLength

    private

    def expiration_edge_cases_enabled?
      IdentityConfig.store.in_person_proofing_expiration_edge_cases_enabled
    end

    # Skip presence/date validation of id_expiration when the edge-case feature is
    # enabled and the user left the (now optional) date blank or entered a literal
    # placeholder date. An entered real date is always validated, even when a
    # non-date option (MIL/INDEF/No date) is also selected — the date wins.
    def skip_expiration_date_validation?
      return false unless expiration_edge_cases_enabled?

      id_expiration_blank? || placeholder_expiration?
    end

    # True when no expiration date was entered. The memorable-date field submits
    # an all-empty { month:, day:, year: } hash (not nil) when left blank, so an
    # empty hash counts as blank in addition to nil/empty values.
    def id_expiration_blank?
      return true if id_expiration.blank?
      return id_expiration.values.all?(&:blank?) if id_expiration.respond_to?(:values)

      false
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

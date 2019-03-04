module Idv
  module FormProfileValidator
    extend ActiveSupport::Concern

    included do
      validates :dob, :ssn, :state, :zipcode, presence: true

      validate :dob_is_sane

      validates_format_of :zipcode,
                          with: /\A\d{5}(-?\d{4})?\z/,
                          message: I18n.t('idv.errors.pattern_mismatch.zipcode'),
                          allow_blank: true
      validates_format_of :ssn,
                          with: /\A\d{3}-?\d{2}-?\d{4}\z/,
                          message: I18n.t('idv.errors.pattern_mismatch.ssn'),
                          allow_blank: true

      validates :city, presence: true, length: { maximum: 255 }
      validates :first_name, presence: true, length: { maximum: 255 }
      validates :last_name, presence: true, length: { maximum: 255 }
      validates :address1, presence: true, length: { maximum: 255 }
      validates :address2, length: { maximum: 255 }
    end

    private

    def dob_is_sane
      date = parsed_dob

      return if date && dob_in_the_past?(date)

      errors.add :dob, I18n.t('idv.errors.bad_dob')
    end

    def dob_in_the_past?(date)
      date < Time.zone.today
    end

    def parsed_dob
      Date.parse(dob.to_s)
    rescue StandardError
      nil
    end
  end
end

# frozen_string_literal: true

module Idv
  class SsnForm
    include ActiveModel::Model
    ATTRIBUTES = [:ssn].freeze

    attr_accessor :ssn

    validates :ssn, presence: true
    validates_format_of :ssn,
                        with: /\A\d{3}-?\d{2}-?\d{4}\z/,
                        message: I18n.t('idv.errors.pattern_mismatch.ssn'),
                        allow_blank: false

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Ssn')
    end

    def initialize(user)
      @user = user
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors, extra: extra_analytics_attributes)
    end

    def ssn_is_unique?
      return false if ssn.nil?

      @ssn_is_unique ||= DuplicateSsnFinder.new(
        ssn: ssn,
        user: @user,
      ).ssn_is_unique?
    end

    def extra_analytics_attributes
      {
        ssn_is_unique: ssn_is_unique?,
      }
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_ssn_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_ssn_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid ssn attribute"
    end
  end
end

module Idv
  # :reek:InstanceVariableAssumption
  class JurisdictionForm
    include ActiveModel::Model
    include FormJurisdictionValidator

    validates :ial2_consent_given?, acceptance: { message: I18n.t('errors.doc_auth.consent_form') }

    ATTRIBUTES = %i[state ial2_consent_given].freeze

    attr_accessor :state, :ial2_consent_given

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Jurisdiction')
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    def ial2_consent_given?
      @ial2_consent_given == 'true'
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_jurisdiction_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_jurisdiction_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid jurisdiction attribute"
    end
  end
end

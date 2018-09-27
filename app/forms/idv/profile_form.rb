module Idv
  class ProfileForm
    include ActiveModel::Model
    include FormProfileValidator
    include FormStateIdValidator

    PROFILE_ATTRIBUTES = [
      :state_id_number,
      :state_id_type,
      :state_id_jurisdiction,
      *Pii::Attributes.members,
    ].freeze

    attr_reader :user
    attr_accessor(*PROFILE_ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    def initialize(user:, previous_params:)
      @user = user
      consume_params(previous_params) if previous_params.present?
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
    end

    def add_sp_unsupported_jurisdiction_error(sp_name)
      error_message = [
        I18n.t('idv.errors.unsupported_jurisdiction'),
        I18n.t('idv.errors.unsupported_jurisdiction_sp', sp_name: sp_name),
      ].join(' ')
      errors.delete(:state)
      errors.add(:state, error_message)
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_profile_parameter_error(key) unless PROFILE_ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_profile_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid profile attribute"
    end
  end
end

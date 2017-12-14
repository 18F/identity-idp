module Idv
  class ProfileForm
    include ActiveModel::Model
    include FormProfileValidator
    include FormStateIdValidator

    PROFILE_ATTRIBUTES = [:state_id_number, :state_id_type, *Pii::Attributes.members].freeze

    attr_reader :user
    attr_accessor(*PROFILE_ATTRIBUTES)

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Profile')
    end

    def initialize(params, user)
      @user = user
      consume_params(params)
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors.messages)
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

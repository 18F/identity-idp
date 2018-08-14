module Idv
  class JurisdictionForm
    include ActiveModel::Model
    include FormJurisdictionValidator

    ATTRIBUTES = [:state].freeze

    attr_reader :state

    def self.model_name
      ActiveModel::Name.new(self, nil, 'Jurisdiction')
    end

    def submit(params)
      self.state = params[:state]

      FormResponse.new(success: valid?, errors: errors.messages, extra: extra_analytics_attributes)
    end

    private

    attr_writer :state

    def extra_analytics_attributes
      {
        state: state,
      }
    end
  end
end

module Idv
  class HowToVerifyForm
    include ActiveModel::Model
    ATTRIBUTES = [:selection].freeze
    REMOTE = 'remote'
    IPP = 'ipp'
    VERIFICATION_OPTIONS = [REMOTE, IPP].freeze

    attr_accessor :selection

    validates :selection, inclusion: {
      in: VERIFICATION_OPTIONS,
    }
    validates :selection, presence: {
      message: proc { I18n.t('errors.doc_auth.how_to_verify_form') },
    }

    def initialize(selection: nil)
      @selection = selection
    end

    def submit(params)
      consume_params(params)

      FormResponse.new(success: valid?, errors: errors)
    end

    private

    def consume_params(params)
      params.each do |key, value|
        raise_invalid_how_to_verify_parameter_error(key) unless ATTRIBUTES.include?(key.to_sym)
        send("#{key}=", value)
      end
    end

    def raise_invalid_how_to_verify_parameter_error(key)
      raise ArgumentError, "#{key} is an invalid how_to_verify attribute"
    end
  end
end

module Api
  class ProfileCreationFormResponse < ::FormResponse
    attr_reader :personal_key

    def initialize(success:, errors: nil, extra: nil, personal_key: nil)
      @personal_key = personal_key
      super(success: success, errors: errors, extra: extra)
    end
  end
end

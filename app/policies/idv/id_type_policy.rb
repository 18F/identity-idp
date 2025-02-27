# frozen_string_literal: true

module Idv
  class IdTypePolicy
    include AbTestingConcern

    def initialize(user:, session:, user_session:, request: nil, current_sp: nil)
      @current_user = user
      @session = session
      @user_session = user_session
      @request = request
      @current_sp = current_sp
    end

    def allow_passport?
      # IdentityConfig.store.dos_passport_enabled && # TODO: update once flag defined
      lexis_nexis? && passport_option_available?
    end

    private

    attr_reader :current_user, :session, :user_session, :request, :current_sp

    def lexis_nexis?
      ab_test_bucket(:DOC_AUTH_VENDOR) == :lexis_nexis ||
        ab_test_bucket(:DOC_AUTH_VENDOR) == :mock
    end

    def passport_option_available?
      true # ab_test_bucket(:PASSPORT) == :available # TODO: update once AB test defined
    end
  end
end

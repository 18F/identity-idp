module Idv
  class WelcomePresenter
    def initialize(sp_session)
      @sp_session = sp_session
    end

    def sp_name
      sp_session.sp_name || APP_NAME
    end

    private

    attr_accessor :sp_session
  end
end

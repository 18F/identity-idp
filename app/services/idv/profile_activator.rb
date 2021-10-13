module Idv
  class ProfileActivator
    def initialize(user:)
      @user = user
    end

    def call
      user.pending_profile&.activate
    end

    private

    attr_reader :user
  end
end

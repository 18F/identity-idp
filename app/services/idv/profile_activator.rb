module Idv
  class ProfileActivator
    def initialize(user:)
      @user = user
    end

    def call
      user.decorate.pending_profile&.activate
      CreateVerifiedAccountEvent.new(user).call
    end

    private

    attr_reader :user
  end
end

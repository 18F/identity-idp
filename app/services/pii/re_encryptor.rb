module Pii
  class ReEncryptor
    def initialize(user, user_session)
      @user = user
      @user_session = user_session
    end

    def perform
      profile.encrypt_recovery_pii(pii_attributes)
      profile.save!
    end

    private

    attr_reader :user, :user_session

    def pii_attributes
      cacher.fetch
    end

    def cacher
      @_cacher ||= Pii::Cacher.new(user, user_session)
    end

    def profile
      user.active_profile
    end
  end
end

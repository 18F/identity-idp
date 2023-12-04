module Pii
  class ReEncryptor
    def initialize(user: nil, user_session: nil, pii: nil)
      @user = user
      @user_session = user_session
      @pii_attributes = pii
    end

    def perform
      profile.encrypt_recovery_pii(pii_attributes)
      profile.save!
    end

    private

    attr_reader :user, :user_session

    def pii_attributes
      @pii_attributes ||= cacher.fetch
    end

    def cacher
      @cacher ||= Pii::Cacher.new(user, user_session)
    end

    def profile
      user.active_profile
    end
  end
end

module Pii
  class ReEncryptor
    def initialize(user: nil, user_session: nil)
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
      @pii_attributes ||= cacher.fetch(profile.id)
    end

    def cacher
      @cacher ||= Pii::Cacher.new(user, user_session)
    end

    def profile
      @profile ||= user.active_or_pending_profile
    end
  end
end

# frozen_string_literal: true

class BannedUserResolver
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def banned_for_sp?(issuer:)
    user.sign_in_restrictions.where(service_provider: [nil, issuer]).any?
  end
end

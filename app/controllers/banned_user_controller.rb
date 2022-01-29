class BannedUserController < ApplicationController
  def show
    analytics.track_event(Analytics::BANNED_USER_VISITED)
  end
end

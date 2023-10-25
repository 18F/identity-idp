# frozen_string_literal: true

class BannedUserController < ApplicationController
  def show
    analytics.banned_user_visited
  end
end

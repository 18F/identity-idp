# frozen_string_literal: true

module Users
  class DuplicateProfilesPleaseCallController < ApplicationController
    def show
      analytics.one_account_duplicate_profiles_please_call_visited(
        source: params[:source],
      )
    end
  end
end

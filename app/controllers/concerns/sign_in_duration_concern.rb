# frozen_string_literal: true

module SignInDurationConcern
  extend ActiveSupport::Concern

  def sign_in_duration_seconds
    return unless session[:sign_in_page_visited_at]
    (Time.zone.now - Time.zone.parse(session[:sign_in_page_visited_at])).seconds.to_f
  end
end

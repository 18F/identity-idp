# frozen_string_literal: true

class RobotsController < ApplicationController
  ALLOWED_ROUTES = %i[
    new_user_session
    forgot_password
    sign_up_email
  ].to_set.freeze

  def index
    render plain: [
      'User-agent: *',
      'Disallow: /',
      *allowed_paths.map { |path| "Allow: #{path}$" },
    ].join("\n")
  end

  private

  def allowed_paths
    I18n.available_locales
      .map { |locale| locale == I18n.default_locale ? nil : locale }
      .flat_map do |locale|
        ALLOWED_ROUTES.map { |route| route_for(route, only_path: true, locale:) }
      end
  end
end

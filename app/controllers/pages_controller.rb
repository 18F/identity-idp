class PagesController < ApplicationController
  skip_before_action :handle_two_factor_authentication
  before_action :skip_session_expiration

  def page_not_found
    render layout: false, status: 404
  end
end

class PagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :skip_session_expiration
  skip_before_action :disable_caching

  def page_not_found
    render layout: false, status: :not_found, formats: :html
  end
end

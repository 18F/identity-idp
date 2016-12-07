class PagesController < ApplicationController
  def page_not_found
    render layout: false, status: 404
  end
end

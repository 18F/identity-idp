# frozen_string_literal: true

class ReturnToSpPresenter
  include Rails.application.routes.url_helpers

  attr_reader :return_to_sp_url

  def initialize(return_to_sp_url:)
    @return_to_sp_url = return_to_sp_url
  end
end

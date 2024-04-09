# frozen_string_literal: true

class RedirectToSpPresenter
  attr_reader :redirect_to_sp_url

  def initialize(redirect_to_sp_url:)
    @redirect_to_sp_url = redirect_to_sp_url
  end

  def return_to_sp
    binding.pry
  end
end

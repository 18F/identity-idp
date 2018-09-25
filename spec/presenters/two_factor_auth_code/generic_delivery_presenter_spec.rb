require 'rails_helper'

describe TwoFactorAuthCode::GenericDeliveryPresenter do
  include Rails.application.routes.url_helpers

  it 'is an abstract presenter with methods that should be implemented' do
    presenter = presenter_with

    %w[header help_text fallback_links].each do |m|
      expect { presenter.send(m.to_sym) }.to raise_error(NotImplementedError)
    end
  end

  def presenter_with(arguments = {}, view = ActionController::Base.new.view_context)
    TwoFactorAuthCode::GenericDeliveryPresenter.new(data: arguments, view: view)
  end
end

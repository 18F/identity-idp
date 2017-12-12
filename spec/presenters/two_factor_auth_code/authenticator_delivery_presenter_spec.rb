require 'rails_helper'

describe TwoFactorAuthCode::AuthenticatorDeliveryPresenter do

  it 'handles multiple locales' do
    I18n.available_locales.each do |locale|
      I18n.locale = locale
      presenter.fallback_links.each do |html|
        if locale == :en
          expect(html).not_to match(%r{href="/en/})
        else
          expect(html).to match(%r{href="/#{locale}/})
        end
      end
      if locale == :en
        expect(presenter.cancel_link).not_to match(%r{/en/})
      else
        expect(presenter.cancel_link).to match(%r{/#{locale}/})
      end
    end
  end

  def presenter
    TwoFactorAuthCode::AuthenticatorDeliveryPresenter.new(data: {}, view: ActionController::Base.new.view_context)
  end

end

require 'rails_helper'

def presenter_with(arguments = {})
  TwoFactorAuthCode::GenericDeliveryPresenter.new(arguments)
end

describe TwoFactorAuthCode::GenericDeliveryPresenter do
  it 'is an abstract presenter with methods that should be implemented' do
    presenter = presenter_with

    %w(header help_text fallback_links).each do |m|
      expect do
        presenter.send(m.to_sym)
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#recovery_code_link' do
    context 'with unconfirmed user' do
      presenter = presenter_with(unconfirmed_user: true)

      it 'returns without providing the option to use a recovery code' do
        expect(presenter.recovery_code_link).to be_nil
      end
    end

    context 'with confirmed user' do
      presenter = presenter_with(unconfirmed_user: false)

      it 'returns a recovery code link' do
        expect(presenter.recovery_code_link).not_to be_nil
      end
    end
  end
end

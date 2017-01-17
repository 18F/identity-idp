require 'rails_helper'

describe TwoFactorAuthCode::GenericDeliveryPresenter do
  let(:presenter) { TwoFactorAuthCode::GenericDeliveryPresenter.new({}) }
  it 'is an abstract presenter with methods that should be implemented' do
    %w(header help_text fallback_links).each do |m|
      expect do
        presenter.send(m.to_sym)
      end.to raise_error(NotImplementedError)
    end
  end

  describe '#recovery_code_link' do
    it 'defines a public method that creates a recovery code link' do
      expect(presenter).to respond_to(:recovery_code_link)
    end
  end
end

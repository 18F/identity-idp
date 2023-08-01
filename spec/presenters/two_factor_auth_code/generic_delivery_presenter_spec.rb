require 'rails_helper'

RSpec.describe TwoFactorAuthCode::GenericDeliveryPresenter do
  include Rails.application.routes.url_helpers

  let(:presenter) { presenter_with }

  it 'is an abstract presenter with methods that should be implemented' do
    %w[header].each do |m|
      expect { presenter.send(m.to_sym) }.to raise_error(NotImplementedError)
    end
  end

  describe '#troubleshooting_options' do
    it 'includes default troubleshooting options' do
      expect(presenter.troubleshooting_options.size).to eq(2)
      expect(presenter.troubleshooting_options[0]).to satisfy do |c|
        c.url == login_two_factor_options_path &&
          c.content == t('two_factor_authentication.login_options_link_text')
      end
      expect(presenter.troubleshooting_options[1]).to satisfy do |c|
        c.content == t('two_factor_authentication.learn_more') && c.new_tab?
      end
    end

    context 'with blank link path' do
      before do
        allow(presenter).to receive(:link_path).and_return('')
      end

      it 'includes default troubleshooting options' do
        expect(presenter.troubleshooting_options.size).to eq(1)
        expect(presenter.troubleshooting_options[0]).to satisfy do |c|
          c.new_tab? && c.content == t('two_factor_authentication.learn_more')
        end
      end
    end
  end

  def presenter_with(arguments = {}, view = ActionController::Base.new.view_context)
    TwoFactorAuthCode::GenericDeliveryPresenter.new(
      data: arguments,
      view: view,
      service_provider: nil,
    )
  end
end

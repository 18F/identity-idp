require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInSelectionPresenter do
  let(:placeholder_presenter_class) do
    Class.new(TwoFactorAuthentication::SignInSelectionPresenter)
  end

  let(:user) { build(:user) }
  let(:configuration) { create(:phone_configuration, user: user) }

  subject(:presenter) { placeholder_presenter_class.new(user: user, configuration: configuration) }

  describe '#render_in' do
    it 'renders captured block content' do
      view_context = ActionController::Base.new.view_context

      expect(view_context).to receive(:capture) do |*_args, &block|
        expect(block.call).to eq('content')
      end

      presenter.render_in(view_context) { 'content' }
    end
  end

  describe '#label' do
    it 'raises with missing implementation' do
      expect { presenter.label }.to raise_error(NotImplementedError)
    end
  end

  describe '#type' do
    it 'raises with missing implementation' do
      expect { presenter.type }.to raise_error(NotImplementedError)
    end
  end

  describe '#info' do
    it 'raises with missing implementation' do
      expect { presenter.info }.to raise_error(NotImplementedError)
    end
  end
end

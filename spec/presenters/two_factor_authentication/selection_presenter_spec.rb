require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SelectionPresenter do
  class PlaceholderPresenter < TwoFactorAuthentication::SelectionPresenter
    def method
      :missing
    end
  end

  subject(:presenter) { described_class.new }

  describe '#render_in' do
    it 'renders captured block content' do
      view_context = ActionController::Base.new.view_context

      expect(view_context).to receive(:capture) do |*args, &block|
        expect(block.call).to eq('content')
      end

      presenter.render_in(view_context) { 'content' }
    end
  end

  describe '#disabled?' do
    it { expect(presenter.disabled?).to eq(false) }
  end

  describe '#single_configuration_only?' do
    it { expect(presenter.single_configuration_only?).to eq(false) }
  end

  describe '#mfa_added_label' do
    subject(:mfa_added_label) { presenter.mfa_added_label }

    it 'is a count of configured MFAs' do
      expect(presenter.mfa_added_label).to include('added')
    end

    context 'with single configuration only' do
      before do
        allow(presenter).to receive(:single_configuration_only?).and_return(true)
      end

      it 'is an empty string' do
        expect(presenter.mfa_added_label).to eq('')
      end
    end
  end

  describe '#label' do
    context 'with no configuration' do
      it 'raises with missing translation' do
        expect { PlaceholderPresenter.new.label }.to raise_error(RuntimeError)
      end
    end

    context 'with configuration' do
      it 'raises with missing translation' do
        expect { PlaceholderPresenter.new(configuration: 1).label }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#info' do
    context 'with no configuration' do
      it 'raises with missing translation' do
        expect { PlaceholderPresenter.new.info }.to raise_error(RuntimeError)
      end
    end

    context 'with configuration' do
      it 'raises with missing translation' do
        expect { PlaceholderPresenter.new(configuration: 1).info }.to raise_error(RuntimeError)
      end
    end
  end
end

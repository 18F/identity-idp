require 'rails_helper'

RSpec.describe TwoFactorAuthentication::SignInPivCacSelectionPresenter do
  let(:user) { create(:user) }
  let(:configuration) { create(:piv_cac_configuration, user: user) }

  let(:presenter) do
    described_class.new(user: user, configuration: configuration)
  end

  describe '#type' do
    it 'returns piv_cac' do
      expect(presenter.type).to eq :piv_cac
    end
  end

  describe '#render_in' do
    let(:user_session) { {} }
    let(:view_context) { ActionController::Base.new.view_context }

    before do
      allow(view_context).to receive(:user_session).and_return(user_session)
    end

    it 'assigns disabled instance variable to false ahead of capture' do
      expect(view_context).to receive(:capture) do
        expect(presenter.instance_variable_get(:@disabled)).to eq(false)
      end

      presenter.render_in(view_context)
    end

    it 'renders captured block content' do
      expect(view_context).to receive(:capture) do |*_args, &block|
        expect(block.call).to eq('content')
      end

      presenter.render_in(view_context) { 'content' }
    end

    context 'when view context user session incudes add_piv_cac_after_2fa key' do
      let(:user_session) { { add_piv_cac_after_2fa: :anything } }

      it 'assigns disabled instance variable to true ahead of capture' do
        expect(view_context).to receive(:capture) do
          expect(presenter.instance_variable_get(:@disabled)).to eq(true)
        end

        presenter.render_in(view_context)
      end
    end
  end

  describe '#label' do
    it 'returns the label text' do
      expect(presenter.label).to eq(
        t('two_factor_authentication.two_factor_choice_options.piv_cac'),
      )
    end
  end

  describe '#info' do
    it 'returns the info text' do
      expect(presenter.info).to eq(
        t('two_factor_authentication.login_options.piv_cac_info'),
      )
    end
  end

  describe '#disabled?' do
    subject(:disabled?) { presenter.disabled? }

    context 'when disabled instance variable is unassigned' do
      it { is_expected.to eq(false) }
    end

    context 'when disabled instance variable is false' do
      before { presenter.instance_variable_set(:@disabled, false) }

      it { is_expected.to eq(false) }
    end

    context 'when disabled instance variable is true' do
      before { presenter.instance_variable_set(:@disabled, true) }

      it { is_expected.to eq(true) }
    end
  end
end

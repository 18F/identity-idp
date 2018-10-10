require 'rails_helper'

describe TwoFactorLoginOptionsPresenter do
  include Rails.application.routes.url_helpers

  let(:user) { User.new }
  let(:view) { ActionController::Base.new.view_context }
  let(:presenter) do
    TwoFactorLoginOptionsPresenter.new(user, view, nil)
  end

  it 'supplies a title' do
    expect(presenter.title).to eq \
      t('two_factor_authentication.login_options_title')
  end

  it 'supplies a heading' do
    expect(presenter.heading).to eq \
      t('two_factor_authentication.login_options_title')
  end

  it 'supplies a cancel link when the token is valid' do
    allow_any_instance_of(TwoFactorLoginOptionsPresenter).to \
      receive(:account_reset_token_valid?).and_return(true)

    allow_any_instance_of(TwoFactorLoginOptionsPresenter).to \
      receive(:account_reset_token).and_return('foo')

    expect(presenter.account_reset_or_cancel_link).to eq \
      t('two_factor_authentication.account_reset.pending_html',
        cancel_link: view.link_to(
          t('two_factor_authentication.account_reset.cancel_link'),
          account_reset_cancel_url(token: 'foo')
        ))
  end

  it 'supplies a reset link when the token is not valid' do
    allow_any_instance_of(TwoFactorLoginOptionsPresenter).to \
      receive(:account_reset_token_valid?).and_return(false)

    expect(presenter.account_reset_or_cancel_link).to eq \
      t('two_factor_authentication.account_reset.text_html',
        link: view.link_to(
          t('two_factor_authentication.account_reset.link'),
          account_reset_request_path(locale: LinkLocaleResolver.locale)
        ))
  end

  context 'with multiple webauthn configurations' do
    let(:user) { create(:user) }
    before(:each) do
      create_list(:webauthn_configuration, 2, user: user)
      user.webauthn_configurations.reload
    end

    it 'has only one webauthn selection presenter' do
      webauthn_selection_presenters = presenter.options.map(&:class).select do |klass|
        klass == TwoFactorAuthentication::WebauthnSelectionPresenter
      end
      expect(webauthn_selection_presenters.count).to eq 1
    end
  end
end

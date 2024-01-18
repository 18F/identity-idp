require 'rails_helper'

RSpec.describe ManageableAuthenticatorComponent, type: :component do
  include Rails.application.routes.url_helpers

  let(:configuration_name) { 'Example Configuration' }
  let(:configuration) { create(:webauthn_configuration, name: configuration_name) }
  let(:user_session) { {} }
  let(:reauthenticate_at) { Time.zone.now }
  let(:manage_api_url) { '/api/manage' }
  let(:manage_url) { '/manage' }
  let(:options) { { configuration:, user_session:, manage_api_url:, manage_url: } }
  let(:component) { ManageableAuthenticatorComponent.new(**options) }
  subject(:rendered) { render_inline component }

  around do |example|
    freeze_time { example.run }
  end

  before do
    auth_methods_session = instance_double('AuthMethodsSession', reauthenticate_at:)
    allow(component).to receive(:auth_methods_session).and_return(auth_methods_session)
  end

  it 'renders with initializing attributes' do
    rendered

    element = page.find_css('lg-manageable-authenticator').first

    expect(element.attr('api-url')).to eq(manage_api_url)
    expect(element.attr('configuration-name')).to eq(configuration_name)
    expect(element.attr('unique-id')).to eq(component.unique_id)
    expect(element.attr('reauthenticate-at')).to eq(reauthenticate_at.iso8601)
    expect(element.attr('reauthentication-url')).to eq(component.reauthentication_url)
  end

  it 'renders with initializing javascript strings' do
    rendered

    strings_element = page.find_css(
      'script.manageable-authenticator__strings[type="application/json"]',
      visible: false,
    ).first

    expect(JSON.parse(strings_element.text, symbolize_names: true)).to eq(
      renamed: t('components.manageable_authenticator.renamed'),
      deleteConfirm: t('components.manageable_authenticator.delete_confirm'),
      deleted: t('components.manageable_authenticator.deleted'),
    )
  end

  it 'renders with focusable edit panel' do
    rendered

    edit_element = page.find_css('.manageable-authenticator__edit').first

    expect(edit_element.attr('tabindex')).to be_present
    expect(edit_element).to have_name(
      format(
        '%s: %s',
        t('components.manageable_authenticator.manage_accessible_label'),
        configuration.name,
      ),
    )
  end

  it 'initializes content with configuration details' do
    expect(rendered).to have_field(
      t('components.manageable_authenticator.nickname'),
      with: configuration_name,
    )
    expect(rendered).to have_content(configuration_name)
    expect(rendered).to have_content(
      t(
        'components.manageable_authenticator.created_on',
        date: l(configuration.created_at, format: :event_date),
      ),
    )
  end

  it 'renders with buttons that have accessibly distinct manage label' do
    expect(rendered).to have_button(
      format(
        '%s: %s',
        t('components.manageable_authenticator.manage_accessible_label'),
        configuration.name,
      ),
    )
  end

  describe '#reauthentication_url' do
    subject(:reauthentication_url) { component.reauthentication_url }

    it 'includes manage_authenticator query parameter for configuration' do
      rendered

      uri = URI.parse(reauthentication_url)
      params = CGI.parse(uri.query)

      expect(uri.path).to eq(account_reauthentication_path)
      expect(params['manage_authenticator']).to eq(["webauthnconfiguration-#{configuration.id}"])
    end
  end

  describe '#unique_id' do
    subject(:unique_id) { component.unique_id }

    it 'derives an id from the configuration class and id' do
      rendered

      expect(component.unique_id).to eq("webauthnconfiguration-#{configuration.id}")
    end
  end

  describe '#strings' do
    it 'includes default strings' do
      rendered

      expect(component.strings).to eq(
        renamed: t('components.manageable_authenticator.renamed'),
        delete_confirm: t('components.manageable_authenticator.delete_confirm'),
        deleted: t('components.manageable_authenticator.deleted'),
        manage_accessible_label: t('components.manageable_authenticator.manage_accessible_label'),
      )
    end

    context 'with custom strings' do
      let(:custom_rename_string) { 'custom rename string' }
      let(:custom_strings) { { renamed: custom_rename_string } }
      let(:options) do
        { configuration:, user_session:, manage_api_url:, manage_url:, custom_strings: }
      end

      it 'overrides the default strings with provided custom strings' do
        rendered

        expect(component.strings).to eq(
          renamed: custom_rename_string,
          delete_confirm: t('components.manageable_authenticator.delete_confirm'),
          deleted: t('components.manageable_authenticator.deleted'),
          manage_accessible_label: t('components.manageable_authenticator.manage_accessible_label'),
        )
      end

      context 'with custom manage accessible label' do
        let(:custom_manage_accessible_label) { 'Manage' }
        let(:custom_strings) { { manage_accessible_label: custom_manage_accessible_label } }

        it 'overrides button label and affected linked content' do
          manage_label = format('%s: %s', custom_manage_accessible_label, configuration.name)
          expect(rendered).to have_button(manage_label)
          edit_element = page.find_css('.manageable-authenticator__edit').first
          expect(edit_element).to have_name(manage_label)
        end
      end
    end
  end
end

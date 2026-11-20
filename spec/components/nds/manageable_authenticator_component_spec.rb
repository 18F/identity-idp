require 'rails_helper'

RSpec.describe NDS::ManageableAuthenticatorComponent, type: :component do
  let(:configuration) { create(:webauthn_configuration, name: 'Safari on macOS') }
  let(:user_session) { {} }
  let(:reauthenticate_at) { Time.zone.now }
  let(:manage_api_url) { '/api/manage' }
  let(:manage_url) { '/manage' }
  let(:nickname_label) { 'Passkey nickname' }
  let(:options) do
    { configuration:, user_session:, manage_api_url:, manage_url:, nickname_label: }
  end
  let(:component) { described_class.new(**options) }
  subject(:rendered) { render_inline component }

  around do |example|
    freeze_time { example.run }
  end

  before do
    allow_any_instance_of(AlertComponent).to receive(:nds_bucket?).and_return(true)
    allow_any_instance_of(ButtonComponent).to receive(:nds_bucket?).and_return(true)
    auth_methods_session = instance_double('AuthMethodsSession', reauthenticate_at:)
    allow(component).to receive(:auth_methods_session).and_return(auth_methods_session)
  end

  it 'renders the manageable authenticator element opted into inline rename' do
    element = rendered.at_css('lg-manageable-authenticator')

    expect(element['inline-rename']).not_to be_nil
    expect(element['api-url']).to eq(manage_api_url)
    expect(element['configuration-name']).to eq('Safari on macOS')
    expect(element['unique-id']).to eq("webauthnconfiguration-#{configuration.id}")
    expect(element['reauthenticate-at']).to eq(reauthenticate_at.iso8601)
    expect(element['reauthentication-url']).to eq(component.reauthentication_url)
  end

  it 'renders the javascript strings' do
    strings = rendered.at_css('script.manageable-authenticator__strings[type="application/json"]')

    expect(JSON.parse(strings.text, symbolize_names: true)).to eq(
      renamed: t('components.manageable_authenticator.renamed'),
      deleteConfirm: t('components.manageable_authenticator.delete_confirm'),
      deleted: t('components.manageable_authenticator.deleted'),
    )
  end

  it 'renders the summary row with the nickname and created date' do
    summary = rendered.at_css('.manageable-authenticator__summary')
    row = summary.at_css('.auth-methods__row')

    expect(summary['hidden']).to be_nil
    expect(row.at_css('.auth-methods__row-text .manageable-authenticator__name').text)
      .to eq('Safari on macOS')
    expect(row.at_css('.auth-methods__row-text').text).to include(
      t(
        'components.manageable_authenticator.created_on',
        date: l(configuration.created_at, format: :event_date),
      ),
    )
  end

  context 'with details' do
    let(:options) do
      {
        configuration:,
        user_session:,
        manage_api_url:,
        manage_url:,
        nickname_label:,
        details: 'Added on today',
      }
    end

    it 'renders the details in place of the created date' do
      expect(rendered).to have_css('.auth-methods__row-text', text: 'Added on today')
      expect(rendered).not_to have_content(
        t(
          'components.manageable_authenticator.created_on',
          date: l(configuration.created_at, format: :event_date),
        ),
      )
    end
  end

  it 'links to the manage page without javascript and renders a manage button with it' do
    manage_label = [
      t('components.manageable_authenticator.manage_accessible_label'),
      'Safari on macOS',
    ].join(': ')

    expect(rendered).to have_link(
      manage_label,
      href: manage_url,
      class: %w[no-js usa-button--tertiary],
    )
    expect(rendered).to have_button(
      manage_label,
      class: %w[js manageable-authenticator__manage-button usa-button--tertiary],
    )
  end

  it 'renders the hidden edit group, labelled by the manage button' do
    edit = rendered.at_css('.manageable-authenticator__edit')

    expect(edit['hidden']).not_to be_nil
    expect(edit['tabindex']).to eq('-1')
    expect(edit['role']).to eq('group')
    expect(edit['aria-labelledby']).to eq(
      "manageable-authenticator-manage-accessible-label-webauthnconfiguration-#{configuration.id}",
    )
    expect(rendered).to have_css("##{edit['aria-labelledby']}", text: 'Safari on macOS')
  end

  it 'renders the NDS nickname field with the current name' do
    expect(rendered).to have_css(
      'form.manageable-authenticator__rename.auth-methods__row',
      visible: :all,
    )
    expect(rendered).to have_field(nickname_label, with: 'Safari on macOS', visible: :all)
    expect(rendered).to have_css(
      '.usa-input input.usa-input__control.manageable-authenticator__rename-input[maxlength="80"]',
      visible: :all,
    )
  end

  it 'scopes the nickname field id to the configuration' do
    other = create(:auth_app_configuration, name: 'Safari on macOS')
    other_component = described_class.new(**options, configuration: other)
    allow(other_component).to receive(:auth_methods_session)
      .and_return(instance_double('AuthMethodsSession', reauthenticate_at:))

    ids = [render_inline(component), render_inline(other_component)].map do |fragment|
      fragment.at_css('input.manageable-authenticator__rename-input')['id']
    end

    expect(ids.uniq.size).to eq(2)
  end

  it 'renders the delete and save spinner buttons' do
    delete = rendered.at_css('lg-spinner-button.manageable-authenticator__delete-button button')
    save = rendered.at_css('lg-spinner-button.manageable-authenticator__save-rename-button button')

    expect(delete['type']).to eq('button')
    expect(delete['class'].split).to include('usa-button--tertiary', 'account__danger-action')
    expect(delete.text).to include(t('components.manageable_authenticator.delete'))
    expect(save['type']).to eq('submit')
    expect(save['class'].split).not_to include('usa-button--tertiary')
    expect(save.text).to include(t('components.manageable_authenticator.save'))
  end

  it 'renders a hidden success alert for the element messages' do
    container = rendered.at_css('.manageable-authenticator__alert-container')
    alert = container.at_css('.usa-alert.manageable-authenticator__alert')

    expect(container['hidden']).not_to be_nil
    expect(alert['tabindex']).to eq('-1')
    expect(alert.at_css('.usa-alert__text')).to be_present
  end

  it 'does not load the legacy sidecar stylesheet, but keeps the element script' do
    expect(described_class.stylesheets).to be_empty
    expect(described_class.scripts).to include('manageable_authenticator_component')
  end
end

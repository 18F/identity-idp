require 'rails_helper'

describe 'idv/inherited_proofing/get_started.html.erb' do
  let(:flow_session) { {} }
  let(:sp_name) { nil }
  let(:locale) { nil }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
    allow(view).to receive(:flow_session).and_return(flow_session)
    allow(view).to receive(:url_for).and_return('https://www.example.com/')
  end

  it 'renders the Continue button' do
    render template: 'idv/inherited_proofing/get_started'

    expect(rendered).to have_button(t('inherited_proofing.buttons.continue'))
  end

  describe 'I18n' do
    before do
      view.locale = locale

      render template: 'idv/inherited_proofing/get_started'
    end

    context 'with or without service provider' do
      it 'renders troubleshooting options' do
        render template: 'idv/inherited_proofing/get_started'

        expect(rendered).to have_link(t('inherited_proofing.troubleshooting.options.get_va_help'))
        expect(rendered).to have_link(
          t('inherited_proofing.troubleshooting.options.learn_more_phone_or_mail'),
        )
        expect(rendered).not_to have_link(nil, href: idv_inherited_proofing_return_to_sp_path)
        expect(rendered).to have_link(t('inherited_proofing.troubleshooting.options.get_va_help'))
        expect(rendered).to have_link(
          t('inherited_proofing.troubleshooting.options.learn_more_phone_or_mail'),
        )
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        )
      end
    end

    context 'without service provider' do
      it 'renders troubleshooting options' do
        render template: 'idv/inherited_proofing/get_started'

        expect(rendered).to have_link(t('inherited_proofing.troubleshooting.options.get_va_help'))
        expect(rendered).to have_link(
          t('inherited_proofing.troubleshooting.options.learn_more_phone_or_mail'),
        )
        expect(rendered).not_to have_link(nil, href: idv_inherited_proofing_return_to_sp_path)
        expect(rendered).to have_link(t('inherited_proofing.troubleshooting.options.get_va_help'))
        expect(rendered).to have_link(
          t('inherited_proofing.troubleshooting.options.learn_more_phone_or_mail'),
        )
        expect(rendered).to have_link(
          t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name),
        )
      end
    end
  end
end

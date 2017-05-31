require 'rails_helper'

describe 'sign_up/registrations/show.html.slim' do
  context 'when SP is not present' do
    before do
      allow(view).to receive(:decorated_session).and_return(SessionDecorator.new)
    end

    it 'does not include sp-specific copy' do
      render

      expect(rendered).to have_content(
        t('headings.create_account_without_sp', sp: nil)
      )
    end

    it 'has a localized title' do
      expect(view).to receive(:title).with(t('titles.registrations.start'))

      render
    end

    it 'includes a link to create a new account' do
      render

      expect(rendered).
        to have_link(t('sign_up.registrations.create_account'), href: sign_up_email_path)
    end
  end

  context 'when SP is present' do
    before do
      @sp = build_stubbed(:service_provider, friendly_name: 'Awesome Application!')
      view_context = ActionController::Base.new.view_context
      allow(view).to receive(:decorated_session).and_return(
        ServiceProviderSessionDecorator.new(sp: @sp, view_context: view_context, sp_session: {})
      )
    end

    it 'includes sp-specific copy' do
      render

      sp_content = [
        @sp.friendly_name,
        t('headings.create_account_with_sp.sp_text'),
      ].join(' ')

      expect(rendered).to have_content(sp_content)
    end
  end
end

require 'rails_helper'

describe 'users/phone_setup/index.html.erb' do
  before do
    user = build_stubbed(:user)

    allow(view).to receive(:current_user).and_return(user)

    @new_phone_form = NewPhoneForm.new(user)

    @presenter = SetupPresenter.new(
      current_user: user,
      user_fully_authenticated: false,
      user_opted_remember_device_cookie: true,
      remember_device_default: true,
    )
  end

  it 'sets form autocomplete to off' do
    expect(render).to have_xpath("//form[@autocomplete='off']")
  end

  it 'renders a link to choose a different option' do
    expect(render).to have_link(
      t('two_factor_authentication.choose_another_option'),
      href: two_factor_options_path,
    )
  end

  context 'voip numbers' do
    before do
      allow(IdentityConfig.store).to receive(:voip_block).and_return(voip_block)
    end

    context 'when voip numbers are allowed' do
      let(:voip_block) { false }

      it 'does not mention voip' do
        expect(render).to_not have_content(
          t('two_factor_authentication.two_factor_choice_options.phone_info_no_voip'),
        )
      end
    end

    context 'when voip numbers are blocked' do
      let(:voip_block) { true }

      it 'tells users to not use VOIP numbers' do
        expect(render).to have_content(
          t('two_factor_authentication.two_factor_choice_options.phone_info_no_voip'),
        )
      end
    end
  end
end

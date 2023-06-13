require 'rails_helper'

RSpec.describe 'idv/gpo_verify/index.html.erb' do
  let(:user) do
    create(:user)
  end

  let(:pii) do
    {}
  end

  before do
    allow(view).to receive(:step_indicator_steps).and_return({})
    @gpo_verify_form = GpoVerifyForm.new(
      user: user,
      pii: pii,
      otp: '1234',
    )
  end

  context 'user is allowed to request another GPO letter' do
    before do
      @user_can_request_another_gpo_code = true
      render
    end
    it 'includes the send another letter link' do
      expect(rendered).to have_link(t('idv.messages.gpo.resend'), href: idv_gpo_path)
    end
  end
  context 'user is NOT allowed to request another GPO letter' do
    before do
      @user_can_request_another_gpo_code = false
      render
    end
    it 'does not include the send another letter link' do
      expect(rendered).not_to have_link(t('idv.messages.gpo.resend'), href: idv_gpo_path)
    end
  end
end

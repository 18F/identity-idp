describe SpRedirect do
  before do
    class FakeController < ApplicationController
      include SpRedirect

      def index; end
    end
  end

  after do
    Object.send(:remove_const, :FakeController)
  end

  let(:my_controller) { FakeController.new }

  describe '#redirect_url' do
    xit 'redirects to sp when present' do
      user_id = sign_in_as_user[0][0]
      allow(my_controller).to receive(:current_user) { User.first }
      Identity.create!(
        user_id: user_id,
        service_provider: 'sp.example.com',
        authn_context: 'foo',
        last_authenticated_at: Time.current
      )
      allow_any_instance_of(ServiceProvider).
        to receive(:sp_initiated_login_url).and_return('sp.example.com')

      url = my_controller.redirect_url
      expect(url).to eq('sp.example.com')
    end
  end
end

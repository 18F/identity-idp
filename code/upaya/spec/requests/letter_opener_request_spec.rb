describe 'visiting /letter_opener' do
  let(:user) { create(:user, :signed_up) }

  def sign_in_no_2fa(user = create(:user, :signed_up))
    post_via_redirect(
      new_user_session_path,
      'user[email]' => user.email,
      'user[password]' => user.password
    )
  end

  context 'when PT mode enabled' do
    before do
      stub_const('Figaro', double)
      # enable PT mode
      allow(Figaro).to receive_message_chain(:env, :pt_mode) { 'on' }
      # mock other Figaro calls during sign in
      allow(Figaro).to receive_message_chain(:env, :domain_name) { 'example.com' }
      allow(Figaro).to receive_message_chain(:env, :allow_privileged) { 'no' }
      # reload routes so that letter opener is mounted
      Rails.application.reload_routes!
      # ensure clean session
      Warden.test_reset!
    end

    after { Rails.application.reload_routes! }

    context 'when not logged in' do
      it 'is successful' do
        get '/letter_opener'

        expect(response.status).to eq(200)
      end
    end

    context 'when logged in but not 2FA' do
      before { sign_in_no_2fa }

      it 'is successful' do
        get '/letter_opener'

        expect(response.status).to eq(200)
      end
    end
  end

  context 'when PT mode disabled' do
    before do
      stub_const('Figaro', double)
      # enable PT mode
      allow(Figaro).to receive_message_chain(:env, :pt_mode) { 'off' }
      # mock other Figaro calls during sign in
      allow(Figaro).to receive_message_chain(:env, :domain_name) { 'example.com' }
      allow(Figaro).to receive_message_chain(:env, :allow_privileged) { 'no' }
      # reload routes so that letter opener is mounted
      Rails.application.reload_routes!
      # ensure clean session
      Warden.test_reset!
    end

    after { Rails.application.reload_routes! }

    context 'when not logged in' do
      it 'raises a routing error' do
        expect { get '/letter_opener' }.to raise_error(ActionController::RoutingError)
      end
    end

    context 'when logged in but not 2FA' do
      before { sign_in_no_2fa }

      it 'raises a routing error' do
        expect { get '/letter_opener' }.to raise_error(ActionController::RoutingError)
      end
    end
  end
end

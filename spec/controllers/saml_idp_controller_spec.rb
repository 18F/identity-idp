describe SamlIdpController do
  render_views

  describe '/api/saml/logout' do
    it 'calls UserOtpSender#reset_otp_state' do
      user = create(:user, :signed_up)
      sign_in user

      otp_sender = instance_double(UserOtpSender)
      allow(UserOtpSender).to receive(:new).with(user).and_return(otp_sender)

      expect(otp_sender).to receive(:reset_otp_state)

      delete :logout
    end
  end
end

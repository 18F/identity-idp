shared_examples_for 'an otp form' do
  describe 'tertiary form actions' do
    it 'allows the user to cancel out of the sign in process' do
      render
      expect(rendered).to have_link(t('links.cancel'), destroy_user_session_path)
    end
  end
end

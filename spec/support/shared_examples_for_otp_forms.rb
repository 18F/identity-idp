RSpec.shared_examples_for 'an otp form' do
  describe 'tertiary form actions' do
    it 'allows the user to cancel out of the sign in process' do
      render
      expect(rendered).to have_link(t('links.cancel'), href: sign_out_path)
    end
  end
end

shared_examples_for 'personal key page' do
  include XPathHelper

  context 'informational text' do
    context 'modal content' do
      it 'displays the modal title' do
        expect(page).to have_content t('forms.personal_key.title')
      end

      it 'displays the modal instructions' do
        expect(page).to have_content t('forms.personal_key.instructions')
      end
    end
  end
end

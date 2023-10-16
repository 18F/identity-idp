require 'rails_helper'

RSpec.describe 'idv/hybrid_handoff/show.html.erb' do
  before do
    allow(view).to receive(:current_user).and_return(@user)
    @idv_form = Idv::PhoneForm.new(user: build_stubbed(:user), previous_params: nil)
  end

  subject(:rendered) do
    render template: 'idv/hybrid_handoff/show', locals: {
      idv_phone_form: @idv_form,
    }
  end

  context 'with shown phone question' do
    before do
      @phone_question_ab_test_bucket = :show_phone_question
    end

    it 'displays the expected headings from the "b" case' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.upload_from_phone'))
      expect(rendered).to have_selector('h2', text: t('doc_auth.headings.switch_to_phone'))
      expect(rendered).not_to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff'))
      expect(rendered).not_to have_selector('h2', text: t('doc_auth.headings.upload_from_phone'))
    end
  end

  context 'without shown phone question' do
    before do
      @phone_question_ab_test_bucket = :bypass_phone_question
    end

    it 'displays the expected headings from the "a" case' do
      expect(rendered).to have_selector('h1', text: t('doc_auth.headings.hybrid_handoff'))
      expect(rendered).to have_selector('h2', text: t('doc_auth.headings.upload_from_phone'))
      expect(rendered).not_to have_selector('h1', text: t('doc_auth.headings.upload_from_phone'))
      expect(rendered).not_to have_selector('h2', text: t('doc_auth.headings.switch_to_phone'))
    end
  end
end

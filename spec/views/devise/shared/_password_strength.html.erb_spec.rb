require 'rails_helper'

describe 'devise/shared/_password_strength.html.erb' do
  let(:forbidden_passwords) { nil }

  before(:each) do
    allow(view).to receive(:forbidden_passwords).and_return(forbidden_passwords)
  end

  describe 'forbidden attributes' do
    context 'when local is unassigned' do
      let(:forbidden_passwords) { nil }

      it 'omits data-forbidden attribute from strength text tag' do
        render

        expect(rendered).to have_selector('#pw-strength-txt:not([data-forbidden])')
      end
    end

    context 'when local is assigned' do
      let(:forbidden_passwords) { ['a', 'b', 'c'] }

      it 'adds JSON-encoded data-forbidden to strength text tag' do
        render

        expect(rendered).to have_selector('#pw-strength-txt[data-forbidden="[\"a\",\"b\",\"c\"]"]')
      end
    end
  end
end

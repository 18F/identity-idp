require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#title' do
    let(:assigned_title) { nil }
    subject(:title) { helper.title }

    before do
      helper.title = assigned_title if assigned_title
    end

    context 'with a title assigned' do
      let(:assigned_title) { 'example' }

      it 'returns the assigned title' do
        expect(title).to eq(assigned_title)
      end
    end

    context 'without a title assigned' do
      let(:raise_on_missing_title) { nil }

      before do
        allow(IdentityConfig.store).to receive(:raise_on_missing_title).
          and_return(raise_on_missing_title)
      end

      context 'configured not to raise on missing title' do
        let(:raise_on_missing_title) { false }

        it 'returns an empty string' do
          expect(title).to eq('')
        end

        it 'notices an error' do
          expect(NewRelic::Agent).to receive(:notice_error).with(
            instance_of(ApplicationHelper::MissingTitleError),
          )

          title
        end
      end

      context 'configured not to raise on missing title' do
        let(:raise_on_missing_title) { true }

        it 'raises an error' do
          expect { title }.to raise_error(ApplicationHelper::MissingTitleError)
        end
      end
    end
  end

  describe '#title=' do
    let(:title) { 'example' }

    it 'assigns the title region content' do
      helper.title = title

      expect(helper.view_flow.get(:title)).to eq(title)
    end
  end

  describe '#session_with_trust?' do
    context 'no user present' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
      end

      context 'current path is new session path' do
        it 'returns false' do
          allow(helper).to receive(:current_page?).with(
            controller: '/users/sessions', action: 'new',
          ).and_return(true)

          expect(helper.session_with_trust?).to eq false
        end
      end

      context 'current path is not new session path' do
        it 'returns true' do
          allow(helper).to receive(:current_page?).with(
            controller: '/users/sessions', action: 'new',
          ).and_return(false)

          expect(helper.session_with_trust?).to eq true
        end
      end
    end

    context 'curent user is present' do
      it 'returns true' do
        allow(controller).to receive(:current_user).and_return(true)

        expect(helper.session_with_trust?).to eq true
      end
    end
  end
end

require 'rails_helper'
require 'rake'

RSpec.describe 'events rake tasks', type: :task do
  let(:task_name) { 'events:delete_max_attempts_reached' }
  let(:target_event_type) { 28 }

  before do
    Rake.application.rake_require 'tasks/events'
    Rake::Task.define_task(:environment)
    Rake::Task[task_name].reenable

    ENV['BATCH_SIZE'] = '1'
  end

  after do
    ENV.delete('BATCH_SIZE')
  end

  describe 'events:delete_max_attempts_reached' do
    subject(:task) { Rake::Task[task_name].execute }

    it 'prints a message when there is nothing to delete' do
      expect { task }.to output("No events found with event_type=28.\n").to_stderr
    end

    context 'with matching events' do
      let!(:first_matching_event) { create(:event) }
      let!(:other_event) { create(:event) }
      let!(:second_matching_event) { create(:event) }

      before do
        Event.where(id: [first_matching_event.id, second_matching_event.id]).update_all(
          event_type: target_event_type,
        )
      end

      it 'deletes only rows with the stored event_type value' do
        expect { task }.to output("Deleted 2 events with event_type=28.\n").to_stdout

        expect(Event.exists?(first_matching_event.id)).to eq(false)
        expect(Event.exists?(other_event.id)).to eq(true)
        expect(Event.exists?(second_matching_event.id)).to eq(false)
      end
    end
  end
end

require 'rails_helper'
require 'rake'

RSpec.describe 'ab tests rake tasks', type: :task do
  before do
    Rake.application.rake_require 'tasks/ab_tests'
    Rake::Task.define_task(:environment)
  end

  describe 'ab_tests:delete_outdated' do
    subject(:task) { Rake::Task['ab_tests:delete_outdated'].execute }

    before { Rake::Task['ab_tests:delete_outdated'].reenable }

    context 'without outdated test assignments' do
      it 'prints message that there is nothing to do' do
        expect { task }.to output("No outdated test assignments to delete!\n").to_stderr
      end
    end

    context 'with outdated test assignments' do
      before do
        # Create multiples of an outdated test to verify that only distinct test names are shown
        create_list(:ab_test_assignment, 2, experiment: 'outdated')
        # Create multiple types of oudated tests to verify that all outdated test names are shown
        create(:ab_test_assignment, experiment: 'outdated2')
        # Create an assignment for an actively-configured test to verify that they are unaffected
        create(:ab_test_assignment)
      end

      it 'lists outdated test assignments but does not delete them' do
        expect { task }.to output(
          <<~STR,
            Found outdated test assignments with experiment names:
              - outdated
              - outdated2

            Re-run command with `confirm` arg to delete:

              rake "ab_tests:delete_outdated[confirm]"

          STR
        ).to_stdout

        expect(AbTestAssignment.count).to eq(4)
      end

      context 'with confirm arg' do
        subject(:task) { Rake.application.invoke_task('ab_tests:delete_outdated[confirm]') }

        it 'deletes outdated test assignments' do
          expect($stdout).to receive(:write).with(/AbTestAssignment Pluck/)
          expect($stdout).to receive(:write).with(/AbTestAssignment Delete All/)
          expect { task }.to output(
            <<~STR,
              Found outdated test assignments with experiment names:
                - outdated
                - outdated2


              Successfully deleted 3 records.
            STR
          ).to_stdout

          expect(AbTestAssignment.count).to eq(1)
        end
      end
    end
  end
end

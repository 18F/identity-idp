require 'rails_helper'

RSpec.describe 'Events DSL' do
  subject do
    Class.new do
      include Idv::Engine::Events::Dsl
      namespace :idv do
        event :started do
          description "The user starts IdV"
        end

        namespace :gpo do

        end
      end
    end
  end

  it 'has the right root namespaces' do
    expect(subject.namespaces).to eql(
      [
        :idv,
      ],
    )
  end
end

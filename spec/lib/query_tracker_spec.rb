require 'rails_helper'
require 'query_tracker'

RSpec.describe QueryTracker do
  describe '#track' do
    it 'tracks queries' do
      queries = QueryTracker.track do
        User.find_by(uuid: 'abdef')
        User.create
      end

      expect(queries[:users].length).to eq(2)
      expect(queries[:users].map(&:first)).to eq([:select, :insert])
    end

    it 'tracks queries with complex joins' do
      queries = QueryTracker.track do
        ActiveRecord::Base.connection.execute <<-SQL
          SELECT *
          FROM doc_auth_logs
          LEFT JOIN
            service_providers ON service_providers.issuer = doc_auth_logs.issuer
          LEFT JOIN
            agencies ON service_providers.agency_id = agencies.id
          LEFT JOIN
            profiles ON profiles.user_id = doc_auth_logs.user_id
        SQL
      end

      expect(queries[:doc_auth_logs].length).to eq(1)
      expect(queries[:service_providers].length).to eq(1)
      expect(queries[:agencies].length).to eq(1)
      expect(queries[:profiles].length).to eq(1)
    end
  end
end

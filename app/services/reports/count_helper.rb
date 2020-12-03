module Reports
  module CountHelper
    module_function

    # Run a COUNT(*), but in size-limited batches to minimize long-running queries
    # Similar to ActiveRecord#find_in_batches, but uses #pluck to minimize allocations
    def count_in_batches(activerecord_relation, batch_size: 10_000)
      count = 0
      min_id = nil
      id_col = activerecord_relation.arel_table[:id]

      loop do
        scoped_relation = if min_id
                            activerecord_relation.where(id_col.gt(min_id))
                          else
                            activerecord_relation
                          end

        ids = scoped_relation.
              limit(batch_size).
              order(:id).
              pluck(:id)

        break if ids.empty?

        count += ids.size
        min_id = ids.last
      end

      count
    end
  end
end

# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `Reports::FraudMetricsReport`.
# Please instead update this file by running `bin/tapioca dsl Reports::FraudMetricsReport`.


class Reports::FraudMetricsReport
  class << self
    sig do
      params(
        date: T.untyped,
        block: T.nilable(T.proc.params(job: Reports::FraudMetricsReport).void)
      ).returns(T.any(Reports::FraudMetricsReport, FalseClass))
    end
    def perform_later(date = T.unsafe(nil), &block); end

    sig { params(date: T.untyped).returns(T.untyped) }
    def perform_now(date = T.unsafe(nil)); end
  end
end
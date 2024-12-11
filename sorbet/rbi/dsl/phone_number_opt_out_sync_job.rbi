# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `PhoneNumberOptOutSyncJob`.
# Please instead update this file by running `bin/tapioca dsl PhoneNumberOptOutSyncJob`.


class PhoneNumberOptOutSyncJob
  class << self
    sig do
      params(
        _now: T.untyped,
        block: T.nilable(T.proc.params(job: PhoneNumberOptOutSyncJob).void)
      ).returns(T.any(PhoneNumberOptOutSyncJob, FalseClass))
    end
    def perform_later(_now, &block); end

    sig { params(_now: T.untyped).returns(T.untyped) }
    def perform_now(_now); end
  end
end
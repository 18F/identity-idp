module Vot
  class Parser
    Result = Data.define(
      :component_values,
      :aal2?,
      :phishing_resistant?,
      :hspd12?,
      :identity_proofing?,
      :biometric_comparison?,
      :ialmax?,
    ) do
      def self.no_sp_result
        self.new(
          component_values: [],
          aal2?: false,
          phishing_resistant?: false,
          hspd12?: false,
          identity_proofing?: false,
          biometric_comparison?: false,
          ialmax?: false,
        )
      end

      def aal_level_requested
        if aal2?
          2
        else
          1
        end
      end

      def ial_value_requested
        if ialmax?
          0
        elsif identity_proofing?
          2
        else
          1
        end
      end

      def ial2_requested?
        identity_proofing?
      end

      def ialmax_requested?
        ialmax?
      end

      def piv_cac_requested?
        hspd12?
      end
    end
  end
end

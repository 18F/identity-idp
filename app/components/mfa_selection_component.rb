class MfaSelectionComponent < BaseComponent
    attr_reader :form, :option

    alias_method :f, :form

    def initialize(form:, option:)
    @form = form
    @option = option
    end

end

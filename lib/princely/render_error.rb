module Princely
  class RenderError < StandardError

    attr_accessor :render_errors

    def initialize(render_errors)
      @render_errors = render_errors
    end

    def message
      "Prince couldn't render the pdf, errors:\n\t#{render_errors.join("\n\t")}"
    end
  end
end

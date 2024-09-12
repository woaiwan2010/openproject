# frozen_string_literal: true

module Patterns
  # @hidden
  class FormsPreview < ViewComponent::Preview
    # @display min_height 500px
    def default
      render_with_template
    end
  end
end

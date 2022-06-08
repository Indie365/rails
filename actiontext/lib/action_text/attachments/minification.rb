# frozen_string_literal: true

module ActionText
  module Attachments
    module Minification
      extend ActiveSupport::Concern

      class_methods do
        def fragment_by_minifying_attachments(content)
          Fragment.wrap(content).replace(ActionText::Attachment.tag_name) do |node|
            Document.set_inner_html(node, "")
          end
        end
      end
    end
  end
end

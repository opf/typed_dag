module TypedDag
  module Specs
    module Helpers
      def from_one_or_array(message)
        if from_limit == 1
          message
        else
          Array(message)
        end
      end

      def message_with_from(text, parent)
        if from_limit == 1
          Message.create text: text, from => from_one_or_array(parent)
        else
          m = Message.create text: text
          m.send("#{from}=", from_one_or_array(parent))
          m
        end
      end

      def create_message_with_invalidated_by(text, invalidated_by)
        message = Message.create text: text
        message.invalidated_by = Array(invalidated_by)
        message
      end
    end
  end
end

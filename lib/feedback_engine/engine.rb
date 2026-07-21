# frozen_string_literal: true

module FeedbackEngine
  class Engine < ::Rails::Engine
    isolate_namespace FeedbackEngine

    initializer 'feedback_engine.helper' do
      ActiveSupport.on_load(:action_view) do
        include FeedbackEngine::WidgetHelper
      end
    end
  end
end

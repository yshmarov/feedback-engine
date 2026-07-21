# frozen_string_literal: true

module FeedbackEngine
  # Included into the host's ActionView. Drop `<%= feedback_engine_tag %>`
  # before </body> in your layout; it renders nothing unless feedback is
  # enabled for the request.
  module WidgetHelper
    def feedback_engine_tag
      return unless FeedbackEngine.enabled?(request)

      Widget.snippet(
        endpoint: FeedbackEngine.config.feedbacks_endpoint,
        locale: I18n.locale,
        nonce: (content_security_policy_nonce if respond_to?(:content_security_policy_nonce))
      ).html_safe
    end
  end
end

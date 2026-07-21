# frozen_string_literal: true

require 'feedback_engine/version'
require 'feedback_engine/configuration'
require 'feedback_engine/widget'
require 'feedback_engine/engine'

# In-app product feedback collection for Rails. A drop-in widget lets users
# send bug reports, feature requests, and general feedback (with screenshots)
# from any page; submissions land in your own database, with a minimal built-in
# dashboard to browse and triage them.
module FeedbackEngine
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Can this request send feedback? Checked on the server for the endpoint
    # and by the helper before rendering the widget.
    def enabled?(request)
      !!config.enabled.call(request)
    end

    # Can this request browse and triage feedback? Checked by every dashboard
    # action.
    def admin?(request)
      !!config.authorize_admin.call(request)
    end
  end
end

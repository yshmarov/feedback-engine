# frozen_string_literal: true

module FeedbackEngine
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    private

    def current_author
      return @current_author if defined?(@current_author)

      @current_author = FeedbackEngine.config.current_user.call(request)
    end
  end
end

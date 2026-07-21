# frozen_string_literal: true

module FeedbackEngine
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end

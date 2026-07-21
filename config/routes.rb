# frozen_string_literal: true

FeedbackEngine::Engine.routes.draw do
  # create is the public widget endpoint; the rest is the triage dashboard.
  resources :feedbacks, only: %i[create index show update destroy]

  root to: 'feedbacks#index'
end

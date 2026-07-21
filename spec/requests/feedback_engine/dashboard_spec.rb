# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feedback dashboard', type: :request do
  def create_feedback(**attrs)
    FeedbackEngine::Feedback.create!({ kind: 'bug', message: 'It broke' }.merge(attrs))
  end

  context 'when not authorized (the default outside development)' do
    it 'forbids the index' do
      get '/feedback'
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids updates' do
      feedback = create_feedback
      patch "/feedback/feedbacks/#{feedback.id}", params: { feedback: { status: 'resolved' } }
      expect(response).to have_http_status(:forbidden)
      expect(feedback.reload.status).to eq('open')
    end
  end

  context 'when authorized' do
    before do
      FeedbackEngine.config.authorize_admin = ->(_request) { true }
    end

    it 'lists open feedback with status counts' do
      create_feedback(message: 'Open bug')
      create_feedback(message: 'Solved one', status: 'resolved')

      get '/feedback'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Open bug')
      expect(response.body).not_to include('Solved one')
    end

    it 'filters by status and kind' do
      create_feedback(message: 'A bug in review', status: 'in_review')
      create_feedback(message: 'A feature idea', kind: 'feature', status: 'in_review')

      get '/feedback', params: { status: 'in_review', kind: 'feature' }

      expect(response.body).to include('A feature idea')
      expect(response.body).not_to include('A bug in review')
    end

    it 'shows one feedback with its details' do
      feedback = create_feedback(section: 'Billing', page_url: 'http://example.com/x',
                                 author_label: 'user@example.com')

      get "/feedback/feedbacks/#{feedback.id}"

      expect(response.body).to include('It broke')
      expect(response.body).to include('Billing')
      expect(response.body).to include('user@example.com')
    end

    it 'renders attached screenshots' do
      feedback = create_feedback
      feedback.screenshots.attach(
        io: File.open(File.expand_path('../../fixtures/tiny.png', __dir__)),
        filename: 'tiny.png',
        content_type: 'image/png'
      )

      get "/feedback/feedbacks/#{feedback.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<img')
      expect(response.body).to include('tiny.png')
    end

    it 'updates the status' do
      feedback = create_feedback

      patch "/feedback/feedbacks/#{feedback.id}", params: { feedback: { status: 'resolved' } }

      expect(response).to have_http_status(:see_other)
      expect(feedback.reload.status).to eq('resolved')
    end

    it 'deletes feedback' do
      feedback = create_feedback

      delete "/feedback/feedbacks/#{feedback.id}"

      expect(response).to have_http_status(:see_other)
      expect(FeedbackEngine::Feedback.exists?(feedback.id)).to be(false)
    end
  end
end

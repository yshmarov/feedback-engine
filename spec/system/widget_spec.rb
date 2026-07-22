# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Feedback widget', type: :system do
  let(:png) { File.expand_path('../fixtures/tiny.png', __dir__) }

  it 'submits feedback end to end, with a screenshot' do
    visit '/sample'

    find('#fbe-button').click
    expect(page).to have_css('#fbe-dialog')

    # Client-side validation first: an empty message never leaves the browser.
    click_button 'Send feedback'
    expect(page).to have_text('Please enter a message.')
    expect(FeedbackEngine::Feedback.count).to eq(0)

    select 'Feature request', from: 'Type'
    fill_in 'Your message', with: 'Love it, but add dark mode'
    attach_file 'Screenshots', png

    click_button 'Send feedback'
    expect(page).to have_text('Thanks for your feedback!')

    feedback = FeedbackEngine::Feedback.last
    expect(feedback.kind).to eq('feature')
    expect(feedback.message).to eq('Love it, but add dark mode')
    expect(feedback.page_url).to include('/sample')
    expect(feedback.screenshots.count).to eq(1)
  end

  it 'shows the section select when sections are configured' do
    FeedbackEngine.config.sections = %w[Billing Reports]
    visit '/sample'

    find('#fbe-button').click
    select 'Billing', from: 'Section'
    fill_in 'Your message', with: 'Billing is confusing'
    click_button 'Send feedback'

    expect(page).to have_text('Thanks for your feedback!')
    expect(FeedbackEngine::Feedback.last.section).to eq('Billing')
  end

  it 'closes on Escape without submitting' do
    visit '/sample'

    find('#fbe-button').click
    fill_in 'Your message', with: 'Nearly sent'
    page.driver.browser.action.send_keys(:escape).perform

    expect(page).to have_no_css('#fbe-dialog')
    expect(FeedbackEngine::Feedback.count).to eq(0)
  end

  it 'opens from a host element carrying data-feedback-engine-open' do
    visit '/sample'

    find('#custom-opener').click

    expect(page).to have_css('#fbe-dialog')
  end

  it 'hides the floating button when show_button is off, custom trigger still works' do
    FeedbackEngine.config.show_button = false
    visit '/sample'

    expect(page).to have_no_css('#fbe-button')
    find('#custom-opener').click
    expect(page).to have_css('#fbe-dialog')
  end

  it 'rejects oversized files in the browser before uploading' do
    FeedbackEngine.config.max_screenshot_size = 10
    visit '/sample'

    find('#fbe-button').click
    fill_in 'Your message', with: 'Big file'
    attach_file 'Screenshots', png
    click_button 'Send feedback'

    expect(page).to have_text('A screenshot is too large')
    expect(FeedbackEngine::Feedback.count).to eq(0)
  end
end

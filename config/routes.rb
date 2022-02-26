# frozen_string_literal: true

Rails.application.routes.draw do
  root 'test_events#index'
  post 'test_events/send_event'
  post 'test_events/update_score'
end

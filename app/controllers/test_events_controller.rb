# frozen_string_literal: true

require 'net/https'

class TestEventsController < ApplicationController
  def index
    @net_promoter_score = NetPromoterScore.new
    @net_promoter_scores = NetPromoterScore.all
  end

  def send_event
    publish(net_promoter_score_params.to_h)
    redirect_to '/', notice: 'Event sent'
  end

  # rubocop:disable Metrics/AbcSize
  def update_score
    http = Net::HTTP.new('localhost', '3001')
    request = Net::HTTP::Put.new("/net_promoter_score/#{net_promoter_score_update_params[:token]}",
                                 { 'Content-Type' => 'application/json' })
    request.body = { score: net_promoter_score_update_params[:score] }.to_json
    response = http.request(request)
    case response.code.to_i
    when 200
      redirect_to '/', notice: "Updated the score correctly! Code #{response.code}"
    when 422
      redirect_to '/', notice: "Error updating the score. Code #{response.code}. Message: #{response.body}"
    when 404
      redirect_to '/', notice: "Token not found. Code #{response.code}"
    when 500
      redirect_to '/', notice: "Error in NPS Service. Code #{response.code}"
    else
      redirect_to '/', notice: 'Undefined error'
    end
  end
  # rubocop:enable Metrics/AbcSize

  private

  def net_promoter_score_params
    params[:net_promoter_score].permit(:type, :touchpoint, :respondent_class, :scorable_class, :respondent_id,
                                       :scorable_id)
  end

  def net_promoter_score_update_params
    params[:net_promoter_score].permit(:token, :score)
  end

  def publish(payload)
    return false if payload.nil?

    conn = Bunny.new
    channel = conn.start.create_channel
    exchange = Bunny::Exchange.new(channel, :direct, ENV['BUNNY_AMQP_EXCHANGE'], { durable: true })
    exchange.publish([payload].to_json, routing_key: ENV['CREATE_NPS_QUEUE_NAME'])
    conn.close
  rescue StandardError
    conn.close
    false
  end
end

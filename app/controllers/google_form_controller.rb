class GoogleFormController < ApplicationController
  skip_before_action :verify_authenticity_token

  def input
    form_input = OpenStruct.new(JSON.parse(Sanitizer.basic_sanitize(request.body.read)))
    index_items = (form_input.items || []).index_by { |item| item.item_index.to_i }
    google_form_event = GoogleFormEvent.find_or_initialize_by(url: index_items[1].try(:value).to_s)
    google_form_event.merge_event_attributes(
      attrs: {
        event_id: form_input.form_id,
        title: index_items[0].try(:value).to_s,
        url: index_items[1].try(:value).to_s,
        description: Sanitizer.basic_sanitize(index_items[2].try(:value).to_s),
        address: index_items[7].try(:value).to_s,
        place: index_items[8].try(:value).to_s,
        limit_number: index_items[9].try(:value).to_i,
        cost: index_items[10].try(:value).to_i,
        max_prize: index_items[11].try(:value).to_i,
        currency_unit: 'JPY',
        owner_id: form_input.email,
        started_at: Time.parse([index_items[3].try(:value), index_items[4].try(:value)].join(' ')),
        ended_at: Time.parse([index_items[5].try(:value), index_items[6].try(:value)].join(' ')),
      },
    )
    google_form_event.save!
    render json: google_form_event
  end
end

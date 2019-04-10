class GoogleFormController < ApplicationController
  skip_before_action :verify_authenticity_token

  def input
    form_input = OpenStruct.new(JSON.parse(request.body.read))
    google_form_event = GoogleFormEvent.find_or_initialize_by(event_id: form_input.form_id)
    index_items = (form_input.items || []).index_by{|item| item.item_index.to_i }
    google_form_event.title = index_items[0].try(:value)
    google_form_event.url = index_items[1].try(:value)
    google_form_event.started_at = Time.parse([index_items[2].try(:value), index_items[3].try(:value)].join(" "))
    google_form_event.ended_at = Time.parse([index_items[4].try(:value), index_items[5].try(:value)].join(" "))
    google_form_event.address = index_items[6].try(:value)

    logger.warn(input)
    head(:ok)
  end
end

ActiveAdmin.register Event do
  menu priority: 0, label: 'ハッカソン情報', parent: 'ハッカソン情報'
  config.filters = false
  config.paginate = true

  actions :index, :show, :edit, :update, :new, :create

  index do
    id_column
    column(:title)
    column(:type)
    column(:url) { |a| link_to(a.url, a.url) }
    column('開催期間') do |a|
      message = a.started_at.strftime('%Y年%m月%d日 %H:%M') + ' ~ '
      if a.ended_at.present?
        message += a.ended_at.strftime('%Y年%m月%d日 %H:%M')
      end
      message
    end
    column(:limit_number)
    column(:address)
    column(:place)
    column('緯度経度') { |a| [a.lat, a.lon].join(',') }
    column(:cost) { |a| a.cost.to_s + a.currency_unit }
    column(:max_prize) { |a| a.max_prize.to_s + a.currency_unit }
    column(:attend_number)
    column(:substitute_number)
    actions
  end

  form do |f|
    f.inputs do
      f.input :event_id, as: :string
      f.input :title, as: :string
      f.input :url, as: :string
      li do
        label :started_at
        f.datetime_select(
          :started_at,
          include_seconds: false, default: 7.day.since.change(hour: 10)
        )
      end
      li do
        label :ended_at
        f.datetime_select(
          :ended_at,
          include_seconds: false, default: 8.day.since.change(hour: 20)
        )
      end
      f.input :description, as: :text
      f.input :limit_number, as: :number
      f.input :address, as: :string
      f.input :place, as: :string
      f.input :cost, as: :number, hint: 'めんどくさかったら適当でいいです'
      f.input :max_prize, as: :number, hint: 'めんどくさかったら適当でいいです'
      f.input :currency_unit, as: :string
      f.has_many :hashtags do |h|
        h.input :hashtag, label: 'ハッシュタグ', as: :string
      end
    end
    f.actions
  end

  collection_action :create, method: :post do
    attributes = params.require(:event).permit!
    hashtags_attr = attributes.delete('hashtags_attributes')
    event = SelfPostEvent.new(attributes)
    event.event_id = SecureRandom.hex if event.event_id.blank?
    event.build_location_data
    event.save!
    event.import_hashtags!(
      hashtag_strings: hashtags_attr.values.map(&:values).flatten
    )
    if (Time.current..1.year.since).cover?(event.started_at) &&
       event.hackathon_event?
      TwitterBot.tweet!(
        text: event.generate_tweet_text,
        from: event,
        options: { lat: event.lat, long: event.lon }
      )
    end
    redirect_to({ action: :index }, notice: 'event is created!!')
  end

  collection_action :update, method: :post do
    attributes = params.require(:event).permit!
    SelfPostEvent.find_by!(id: params[:id]).update!(attributes)
    redirect_to({ action: :index }, notice: 'event is updated!!')
  end
end

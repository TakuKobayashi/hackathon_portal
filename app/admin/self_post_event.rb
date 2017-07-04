ActiveAdmin.register Event  do
  menu priority: 0, label: "ハッカソン情報", parent: "ハッカソン情報"

  actions :index, :show, :edit, :update, :new, :create

  index do
    id_column
    column(:title)
    column(:type)
    column(:url){|a| link_to(a.url) }
    column("開催期間") {|a|
      message = a.started_at.strftime("%Y年%m月%d日 %H:%M") + " ~ "
      if a.ended_at.present?
        message += a.ended_at.strftime("%Y年%m月%d日 %H:%M")
      end
      message
    }
    column(:limit_number)
    column(:address)
    column(:place)
    column("緯度経度"){|a| [a.lat, a.lon].join(",")}
    column(:cost) {|a| a.cost.to_s + a.currency_unit }
    column(:max_prize) {|a| a.max_prize.to_s + a.currency_unit }
    column(:attend_number)
    column(:substitute_number)
    actions
  end

  form do |f|
    f.inputs do
      f.input :title, as: :string
      f.input :url, as: :string
      f.input :started_at, as: :datetime_select
      f.input :ended_at, as: :datetime_select
      f.input :limit_number, as: :number
      f.input :address, as: :string
      f.input :place, as: :string
      f.input :cost, as: :number, hint: "めんどくさかったら適当でいいです"
      f.input :max_prize, as: :number, hint: "めんどくさかったら適当でいいです"
      f.input :currency_unit, as: :string
    end
    f.actions
  end

  collection_action :create, method: :post do
    attributes = params.require(:event).permit!
    SelfPostEvent.create!(attributes)
    redirect_to({action: :index}, notice: "event is created!!")
  end

  collection_action :update, method: :post do
    attributes = params.require(:event).permit!
    SelfPostEvent.find_by!(id: params[:id]).update!(attributes)
    redirect_to({action: :index}, notice: "event is updated!!")
  end
end
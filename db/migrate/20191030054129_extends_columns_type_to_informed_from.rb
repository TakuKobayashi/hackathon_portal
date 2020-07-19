class ExtendsColumnsTypeToInformedFrom < ActiveRecord::Migration[6.0]
  def up
    add_column :events, :informed_from, :integer, null: false, default: 0
    add_column :scaling_unity_events, :informed_from, :integer, null: false, default: 0
    Event.where(type: 'Atnd').update_all(informed_from: Event.informed_froms[:atnd])
    Event.where(type: 'Connpass').update_all(informed_from: Event.informed_froms[:connpass])
    Event.where(type: 'Doorkeeper').update_all(informed_from: Event.informed_froms[:doorkeeper])
    Event.where(type: 'Peatix').update_all(informed_from: Event.informed_froms[:peatix])
    Event.where(type: 'Meetup').update_all(informed_from: Event.informed_froms[:meetup])
    Event.where(type: 'GoogleFormEvent').update_all(informed_from: Event.informed_froms[:google_form])
    Event.where(type: 'TwitterEvent').update_all(informed_from: Event.informed_froms[:twitter])
  end

  def down
    remove_column :events, :informed_from
    remove_column :scaling_unity_events, :informed_from
  end
end

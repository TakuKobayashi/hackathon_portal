class ExtendsColumnsTypeToInformedFrom < ActiveRecord::Migration[6.0]
  def up
    add_column :events, :informed_from, :integer, null: false, default: 0
    add_column :scaling_unity_events, :informed_from, :integer, null: false, default: 0
    [Event, Scaling::UnityEvent].each do |clazz|
      clazz.where(type: 'Atnd').update_all(informed_from: clazz.informed_froms[:atnd])
      clazz.where(type: 'Connpass').update_all(informed_from: clazz.informed_froms[:connpass])
      clazz.where(type: 'Doorkeeper').update_all(informed_from: clazz.informed_froms[:doorkeeper])
      clazz.where(type: 'Peatix').update_all(informed_from: clazz.informed_froms[:peatix])
      clazz.where(type: 'Meetup').update_all(informed_from: clazz.informed_froms[:meetup])
      clazz.where(type: 'GoogleFormEvent').update_all(informed_from: clazz.informed_froms[:google_form])
      clazz.where(type: 'TwitterEvent').update_all(informed_from: clazz.informed_froms[:twitter])
    end
  end

  def down
    remove_column :events, :informed_from
    remove_column :scaling_unity_events, :informed_from
  end
end

ActiveAdmin.register TwitterBot do
  menu priority: 0, label: 'Botのつぶやき', parent: 'ハッカソン情報'

  actions :index, :show, :new, :create, :destroy
end

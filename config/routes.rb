Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get '/bms/deleteOrderItem', to: 'bms#deleteOrderItem'
  get '/bms/addOrderItem', to: 'bms#addOrderItem'
end

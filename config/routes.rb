Rails.application.routes.draw do

  root 'dashboard#dashboard'
  
  get '/dashboard_old' => "dashboard#dual_display"

  get '/dashboard' => "dashboard#dashboard"

  get '/dashboard_person' => "dashboard#person_map"

  get '/dashboard_npids' => "dashboard#npids_map"

  get '/ajax_connections' => "dashboard#ajax_connections"

  get '/ajax_person_connections' => "dashboard#ajax_person_connections"

  get '/ajax_npids_distribution' => "dashboard#ajax_npids_distribution"

  get '/dashboard_npids_distribution' => "dashboard#npids_distribution"

  get '/dashboard_burdens' => "dashboard#burdens"

  get '/ajax_burdens' => "dashboard#ajax_burdens"

  get '/ajax_movements' => "dashboard#ajax_movements"

  get '/dashboard_movements' => "dashboard#movements"

  get '/q_sites' => "tasks#query_sites"

  get '/q_connections' => "tasks#query_connections"

  get '/q_ajax_connections' => "tasks#query_ajax_connections"

  get '/q_ajax_person_connections' => "tasks#query_ajax_person_connections"

  get '/q_ajax_npids_distribution' => "tasks#query_ajax_npids_distribution"

  get '/q_ajax_burdens' => "tasks#query_ajax_burdens"

  get '/q_ajax_movements' => "tasks#query_ajax_movements"

  # The priority is based upon order of creation: first created -> highest priority.                              z
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end

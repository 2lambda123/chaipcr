Qpcrctl::Application.routes.draw do
  mount JasmineRails::Engine => '/specs' if defined?(JasmineRails)
  resources :posts

  apipie
  # The priority is based upon order of creation: first created -> highest priority.
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

  root 'main#index'

  get  '/welcome', :to => 'main#welcome', :as => 'welcome'
  get '/login', :to => 'main#login', :as => 'login'
  
  post '/login', :to => 'sessions#create'
  post '/logout', :to => 'sessions#destroy'

  resource :settings, only: [:update, :show]
  resources :users, defaults: { format: 'json' }

  resources :experiments, defaults: { format: 'json' } do
    member do
      post 'start'
      post 'stop'
      post 'copy'
      get 'protocol'
      get 'platessetup'
      get 'status'
      get 'temperature_data'
      get 'fluorescence_data'
      get 'melt_curve_data'
      get 'baseline_subtracted_ct_data'
      get 'export'
      get 'analyze'
    end
  end

  resources :protocols, shallow: true, only: [:update] do
    resources :stages, shallow: true, only: [:create, :update, :destroy] do
      resources :steps, shallow: true, only: [:create, :update, :destroy] do
        resources :ramps, only: [:update]
        post 'move', on: :member
      end
      post 'move', on: :member
    end
  end

  get ':controller(/:action(/:id))'
end

Spree::Core::Engine.routes.append do
  # Add your extension routes here
  namespace :api, defaults: { format: 'json' } do
    resources :shipments do
      member do
        put :update_after_shipped_state
      end
    end

    resources :orders do
      member do
        put :update_store_order_id
      end
    end
  end
end

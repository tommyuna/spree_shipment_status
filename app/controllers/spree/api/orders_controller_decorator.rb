Spree::Api::OrdersController.class_eval do
  def update_store_order_id
    find_order(true)
    authorize! :update, @order, order_token
    unless params[:store] == nil and params[:store_order_id] == nil
      unless @order.shipments == nil
        @order.shipments.each do |shipment|
          shipment.store = params[:store]
          shipment.store_order_id = params[:store_order_id]
          shipment.save
        end
      end
    end
    respond_with(@order, default_template: :show)
  end
end

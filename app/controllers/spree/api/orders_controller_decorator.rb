Spree::Api::OrdersController.class_eval do
  def update_store_order_id
    find_order(true)
    authorize! :update, @order, order_token
    unless params[:json_store_order_id] == nil
      unless @order.shipments == nil
        @order.shipments.each do |shipment|
          params[:json_store_order_id].each do |key, value|
            shipment.push_store_order_id key, value
          end
        end
      end
    end
    respond_with(@order, default_template: :show)
  end
end

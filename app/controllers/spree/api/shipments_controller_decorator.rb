Spree::Api::ShipmentsController.class_eval do
  before_filter :find_and_update_shipment, only: [:ship, :ready, :add, :remove, :update_after_shipped_state]
  def update_after_shipped_state
    state = params[:after_shipped_state]
    unless state == nil
      @shipment.after_shipped_state = state
      respond_with(@shipment, default_template: :show)
      @shipment.save
    end
  end
end

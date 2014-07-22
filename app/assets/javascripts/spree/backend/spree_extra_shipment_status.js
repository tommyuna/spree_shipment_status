// Placeholder manifest file.
// the installer will append this file to the app vendored assets here: vendor/assets/javascripts/spree/backend/all.js'
//

$(function() {
  $('#update_after_shipped_state').on('click', function () {
    var link = $(this);
    var shipment_number = link.data('shipment-number');
    var state = $("#shipment_after_shipped_state").val();
    var url = Spree.url(Spree.routes.shipments_api + '/' + shipment_number + '/update_after_shipped_state.json');
    $.ajax({
      type: 'PUT',
      url: url,
      data: { after_shipped_state: state }
    }).done(function () {
      window.location.reload();
    }).error(function (msg) {
      alert("There's been an error. Come talk to James or Jonghun.");
      console.log(msg);
    });
  });
});

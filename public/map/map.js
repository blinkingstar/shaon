function initialise() {
	var maps = document.getElementsByClassName("map");
	for( var j = 0; j < maps.length; j++ ) {
		var arg = maps[j].innerText;
		if (arg.match(/^coord/i)){
			arg = arg.replace(/^coord/,'');
			var args = arg.split(':');
			var coord = args[0].split(',');
			var pos = new google.maps.LatLng(coord[0],coord[1]);
			var z = 16;
			var address = '';
			if (args[1]){
				var args_z = args[1].split('z');
				if (args_z[1]){
					z = parseInt(args_z[1]);
				}
				address = args_z[0] || '';
			}
			var myOptions = {
				zoom: 16,
				center: pos,
				mapTypeId: google.maps.MapTypeId.ROADMAP
			};
			var map = new google.maps.Map(maps[j], myOptions);
			var marker = new google.maps.Marker({
				map: map, 
				position: pos,
				title: address
			});
			if (address != ''){
				var infowindow = new google.maps.InfoWindow({
					content: '<div>' + address + '</div>',
					maxWidth: '100'
				});
				google.maps.event.addListener(marker, 'click', function() {
					infowindow.open(map,marker);
				});
			}
		}
		else {
			var geocoder = new google.maps.Geocoder();
			var args = arg.split(':');
			var address = args[0];
			var z = 16;
			var resultno = 1;
			if (args[1]){
				var args_z = args[1].split('z');
				if (args_z[1]){
					z = parseInt(args_z[1]);
				}
				resultno = args_z[0] ? parseInt(args_z[0]) : 1;
			}
			resultno--;
			var latlng = new google.maps.LatLng(35.71079, 139.763335);
			var myOptions = {
				zoom: z,
				center: latlng,
				mapTypeId: google.maps.MapTypeId.ROADMAP
			};
			var map = new google.maps.Map(maps[j], myOptions);
			if (geocoder) {
				geocoder.geocode( {'address': address, 'region': 'ja'}, function(results, status) {
					if (status == google.maps.GeocoderStatus.OK) {
						var pos = results[resultno].geometry.location;
						map.setCenter(pos);
						var marker = new google.maps.Marker({
							map: map, 
							position: pos,
							title: address
						});
						var infowindow = new google.maps.InfoWindow({
							content: '<div>' + results[resultno].formatted_address + '</div>',
							maxWidth: '100'
						});
						google.maps.event.addListener(marker, 'click', function() {
							infowindow.open(map,marker);
						});
					} else {
						alert("Geocode was not successful for the following reason: " + status);
					}
				});
			}
		}
	}
}
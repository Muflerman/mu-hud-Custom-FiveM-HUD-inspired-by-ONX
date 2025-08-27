$(document).ready(function(){
    function updatePlayerHUD(data) {
        if (data.health < 100) {
            $('#health-container').fadeIn('slow')
            $('#health').css('height', data.health+"%")
        } else { $('#health-container').fadeOut('slow') }

        if (data.armor > 0) {
            $('#armor-container').fadeIn('slow')
            $('#armor').css('height', data.armor+"%")
        } else { $('#armor-container').fadeOut('slow') }

        if (data.thirst < 100) {
            $('#thirst-container').fadeIn('slow')
            $('#thirst').css('height', data.thirst+"%")
        } else { $('#thirst-container').fadeOut('slow') }

        if (data.hunger < 100) {
            $('#hunger-container').fadeIn('slow')
            $('#hunger').css('height', data.hunger+"%")
        } else { $('#hunger-container').fadeOut('slow') }

        if (data.stamina < 100) {
            $('#stamina-container').fadeIn('slow')
            $('#stamina').css('height', data.stamina+"%")
        } else { $('#stamina-container').fadeOut('slow') }

        if (data.stress > 1) {
            $('#stress-container').fadeIn('slow')
            $('#stress').css('height', data.stress+"%")
        } else { $('#stress-container').fadeOut('slow') }

        // VOZ
        if (data.talking) {
            $('#voice').css('background', "linear-gradient(to top, rgba(255, 255, 0, 0.7), rgba(255, 255, 0, 0.3))");
            $('#voice-container').css({
                'border': '2px solid rgba(255, 255, 0, 0.9)',
                'box-shadow': '0 0 8px rgba(255, 255, 0, 0)'
            });
        } else {
            $('#voice').css('background', "linear-gradient(to top, rgba(255, 255, 255, 0.6), rgba(255, 255, 255, 0.25))");
            $('#voice-container').css({
                'border': '2px solid rgba(255, 255, 255, 0.8)',
                'box-shadow': '0 0 8px rgba(255, 255, 255, 0)'
            });
        }
    }

    function updateVehicleHUD(data) {
        let speedNum = Math.floor(data.speed);
        let speedStr = String(speedNum).padStart(3, '0');
        let zeroCount = 3 - String(speedNum).length;
        let zeroes = speedStr.substring(0, zeroCount);
        let value = speedStr.substring(zeroCount);

        $('#speed').html(
            `<span class="speed-zeroes">${zeroes}</span><span class="speed-value">${value}</span>`
        );

        $('#fuel').text(data.fuel);

        if (data.seatbeltOn === false) {
            $('#seatbelt').css('color', 'red');
        } else {
            $('#seatbelt').css('color', '');
        }

        if (data.gear == 0) {
            $('#gear').text('0')
        } else {
            $('#gear').text(data.gear)
        }

        $('#altitude').text(data.altitude);
        $('#alt-txt').text(data.altitudetexto);
        $('#street1').text(data.street1);
        $('#street2').text(data.street2);
        $('#direction').text(data.direction);
    }

    window.addEventListener('message', function(event) {
        const data = event.data;
        if (data.action == 'showPlayerHUD') {
            $('body').fadeIn('slow')
        } else if (data.action == 'hidePlayerHUD') {
            $('body').fadeOut('slow')
        } else if (data.action == 'updatePlayerHUD') {
            updatePlayerHUD(data)
        } else if (data.action == 'showVehicleHUD') {
            $('#vehicle-hud-container').fadeIn('slow')
        } else if(data.action == 'hideVehicleHUD') {
            $('#vehicle-hud-container').fadeOut('slow')
        } else if (data.action == 'updateVehicleHUD') {
            updateVehicleHUD(data)
        }
    })
});

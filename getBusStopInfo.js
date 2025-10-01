function getMinutesUntilBus(fetched_time) {
    
    let seconds_now = Math.trunc(new Date() / 1000);
    let seconds_at_midnight = Math.trunc(new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate(), 0, 0, 0) / 1000);
    let seconds_since_midnight = seconds_now - seconds_at_midnight;
    let seconds_until_bus = fetched_time - seconds_since_midnight;
    let minutes_until_bus = Math.trunc(seconds_until_bus / 60);

    return minutes_until_bus;
}

const HEADERS = ["bus_type", "bus_num", "bus_direction", "bus_time"]
const INDICES = [0, 1, 5, 3]

function CSVToJSON(csv) {

    var lines = csv.split("\n");
    var result = [];

    for(var i = 1; i < lines.length; i++){

	    var obj = {};
	    var currentline = lines[i].split(",");

	    for(var j = 0; j < HEADERS.length - 1; j++){
		    obj[HEADERS[j]] = currentline[INDICES[j]];
	    }

        obj[HEADERS.at(-1)] = `${getMinutesUntilBus(currentline[INDICES.at(-1)])} min`;

	    result.push(obj);
    }

    return JSON.stringify(result);
}

async function getBusStopInfo(stop_id) {
    const URL = `https://www.stops.lt/vilnius/departures2.php?stopid=${stop_id}`;

    const response = await fetch(URL);
    return CSVToJSON(await response.text());
}
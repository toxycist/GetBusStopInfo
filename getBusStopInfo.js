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

    var lines = csv.trim().split("\n");
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

/**
 * Returns a JSON string, representing an array of buses where each entry has four fields of type string: `bus_type`, `bus_num`, `bus_direction`, `bus_time`.
 * 
 * @param {number} stop_id -
 * - **2016**: Licėjus (Akropolio kryptimi); 
 * - **0710**: Licėjus (Žirmunų kryptimi); 
 * - **0804**: Pramogų arena. Kareivių g. (Žirmūnų kryptimi); 
 * - **0802**: Pramogų arena, Kalvarijų g. (Santariškių kryptimi); 
 * - **0709**: Pramogų arena. Kalvarijų g. (Centro kryptimi); 
 * - **2015**: Pramogų arena. Kareivių g. (Ozo kryptimi); 
 * - **0708**: Tauragnų st. (Centro kryptimi); 
 * - **0803**: Tauragnų st. (Santariškių kryptimi); 
 * - Consult https://docs.google.com/spreadsheets/d/1FaRhmFvxCVLVhHCnEjrGq3l42fSa1R648fk2H3xqHuQ/pubhtml for every available `stop_id`
 * 
 * @returns {string}
 */
async function getBusStopInfo(stop_id) {

    const URL = `https://www.stops.lt/vilnius/departures2.php?stopid=${stop_id}`;

    const response = await fetch(URL);
    return CSVToJSON(await response.text());
}
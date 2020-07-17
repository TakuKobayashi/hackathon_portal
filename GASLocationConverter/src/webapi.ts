function doGet(e: any): GoogleAppsScript.Content.TextOutput {
  const address = e.parameter.address;
  const lat = e.parameter.latitude;
  const lon = e.parameter.longitude;
  const language: string = e.parameter.language || 'ja';
  const returnResult: { [s: string]: any } = {};
  if (address) {
    const normalizeAddress = address.normalize('NFKC');
    const geocodeResponses = convertGeocode(normalizeAddress, language);
    if (geocodeResponses[0]) {
      returnResult.place_id = geocodeResponses[0].place_id;
      returnResult.address = normalizeAddress;
      returnResult.latitude = geocodeResponses[0].geometry.location.lat;
      returnResult.longitude = geocodeResponses[0].geometry.location.lng;
      const postal_code_component = geocodeResponses[0].address_components.find((component) => component.types.includes('postal_code'));
      if (postal_code_component) {
        returnResult.postal_code = postal_code_component.long_name;
      }
    }
  }else if(lat && lon){
    const geocodeResponses = convertReverseGeocode(lat, lon, language);
    if (geocodeResponses[0]) {
      returnResult.place_id = geocodeResponses[0].place_id;
      const formatted_address = geocodeResponses[0].formatted_address.normalize('NFKC');
      const address_parts = formatted_address.split(" ");
      returnResult.address = address_parts[address_parts.length - 1];
      returnResult.latitude = geocodeResponses[0].geometry.location.lat;
      returnResult.longitude = geocodeResponses[0].geometry.location.lng;
      const postal_code_component = geocodeResponses[0].address_components.find((component) => component.types.includes('postal_code'));
      if (postal_code_component) {
        returnResult.postal_code = postal_code_component.long_name;
      }
    }
  }
  const jsonOut = ContentService.createTextOutput();
  //Mime TypeをJSONに設定
  jsonOut.setMimeType(ContentService.MimeType.JSON);
  //JSONテキストをセットする
  jsonOut.setContent(JSON.stringify(returnResult));
  return jsonOut;
}

function convertGeocode(address: string, language: string): any {
  const geocoder = Maps.newGeocoder();
  geocoder.setLanguage(language);
  const responses = geocoder.geocode(address);
  return responses.results;
}

function convertReverseGeocode(lat: number, lon: number, language: string): any {
  const geocoder = Maps.newGeocoder();
  geocoder.setLanguage(language);
  const responses = geocoder.reverseGeocode(lat, lon);
  return responses.results;
}
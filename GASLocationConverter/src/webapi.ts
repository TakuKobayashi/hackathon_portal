function doGet(e: any): GoogleAppsScript.Content.TextOutput {
  const dataKeysColumnNumber: number = e.parameter.keys_column_row || 1;
  const dataStartRowNumber: number = e.parameter.start_row || 2;
  const jsonOut = ContentService.createTextOutput();
  //Mime TypeをJSONに設定
  jsonOut.setMimeType(ContentService.MimeType.JSON);
  //JSONテキストをセットする
  jsonOut.setContent(JSON.stringify({ hello: 11 }));
  return jsonOut;
}

function doPost(e: any): GoogleAppsScript.Content.TextOutput {
  const dataKeysColumnRow: number = e.parameter.keys_column_row || 1;
  const dataStartRowNumber: number = e.parameter.start_row || 2;
  const primaryKeyName = e.parameter.primary_key;

  console.log(e.postData.getDataAsString());
  const data = JSON.parse(e.postData.getDataAsString());
  const jsonOut = ContentService.createTextOutput();
  //Mime TypeをJSONに設定
  jsonOut.setMimeType(ContentService.MimeType.JSON);
  //JSONテキストをセットする
  jsonOut.setContent(JSON.stringify(data));
  return jsonOut;
}

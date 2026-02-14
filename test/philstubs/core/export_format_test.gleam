import gleeunit/should
import philstubs/core/export_format.{Csv, Json}

pub fn from_string_json_test() {
  export_format.from_string("json")
  |> should.equal(Json)
}

pub fn from_string_csv_test() {
  export_format.from_string("csv")
  |> should.equal(Csv)
}

pub fn from_string_unknown_defaults_to_json_test() {
  export_format.from_string("xml")
  |> should.equal(Json)

  export_format.from_string("")
  |> should.equal(Json)

  export_format.from_string("CSV")
  |> should.equal(Json)
}

pub fn content_type_json_test() {
  export_format.content_type(Json)
  |> should.equal("application/json; charset=utf-8")
}

pub fn content_type_csv_test() {
  export_format.content_type(Csv)
  |> should.equal("text/csv; charset=utf-8")
}

pub fn file_extension_json_test() {
  export_format.file_extension(Json)
  |> should.equal(".json")
}

pub fn file_extension_csv_test() {
  export_format.file_extension(Csv)
  |> should.equal(".csv")
}

pub fn to_string_json_test() {
  export_format.to_string(Json)
  |> should.equal("json")
}

pub fn to_string_csv_test() {
  export_format.to_string(Csv)
  |> should.equal("csv")
}

pub fn to_string_roundtrip_test() {
  export_format.to_string(Json)
  |> export_format.from_string
  |> should.equal(Json)

  export_format.to_string(Csv)
  |> export_format.from_string
  |> should.equal(Csv)
}

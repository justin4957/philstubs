import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import philstubs/ui/layout

/// Form data extracted from a template submission, used to repopulate
/// the form on validation errors.
pub type TemplateFormData {
  TemplateFormData(
    title: String,
    description: String,
    body: String,
    suggested_level: String,
    suggested_type: String,
    author: String,
    topics: String,
  )
}

/// Create an empty form data record for a fresh upload form.
pub fn empty_form() -> TemplateFormData {
  TemplateFormData(
    title: "",
    description: "",
    body: "",
    suggested_level: "",
    suggested_type: "bill",
    author: "",
    topics: "",
  )
}

/// Render the template upload form page. Optionally displays validation
/// errors and repopulates fields from previous submission data.
pub fn template_form_page(
  form_data: TemplateFormData,
  validation_error: Option(String),
) -> Element(Nil) {
  layout.page_layout("Upload Template — PHILSTUBS", [
    html.div([attribute.class("template-form-container")], [
      html.h1([], [html.text("Upload a Legislation Template")]),
      html.p([attribute.class("form-description")], [
        html.text(
          "Share model legislation that others can search, browse, and adapt for their jurisdiction.",
        ),
      ]),
      case validation_error {
        Some(error_message) ->
          html.div([attribute.class("form-error")], [
            html.text(error_message),
          ])
        None -> element.none()
      },
      template_form(form_data),
    ]),
  ])
}

fn template_form(form_data: TemplateFormData) -> Element(Nil) {
  html.form(
    [
      attribute.class("template-form"),
      attribute.method("POST"),
      attribute.action("/templates"),
    ],
    [
      form_field("title", "Title", "text", form_data.title, True, [
        attribute.placeholder("e.g., Model Affordable Housing Ordinance"),
      ]),
      form_textarea(
        "description",
        "Description",
        form_data.description,
        True,
        "Briefly describe what this template covers and who it's intended for.",
        3,
      ),
      form_textarea(
        "body",
        "Template Body",
        form_data.body,
        True,
        "Paste the full text of the model legislation here.",
        12,
      ),
      form_select(
        "suggested_level",
        "Suggested Government Level",
        form_data.suggested_level,
        [
          #("federal", "Federal"),
          #("state", "State"),
          #("county", "County"),
          #("municipal", "Municipal"),
        ],
      ),
      form_select(
        "suggested_type",
        "Legislation Type",
        form_data.suggested_type,
        [
          #("bill", "Bill"),
          #("resolution", "Resolution"),
          #("ordinance", "Ordinance"),
          #("bylaw", "Bylaw"),
          #("amendment", "Amendment"),
          #("regulation", "Regulation"),
          #("executive_order", "Executive Order"),
        ],
      ),
      form_field("author", "Author", "text", form_data.author, True, [
        attribute.placeholder("Your name or organization"),
      ]),
      form_field("topics", "Topics", "text", form_data.topics, False, [
        attribute.placeholder("housing, zoning, equity (comma-separated)"),
      ]),
      html.div([attribute.class("form-actions")], [
        html.button(
          [attribute.type_("submit"), attribute.class("submit-button")],
          [html.text("Upload Template")],
        ),
        html.a([attribute.href("/templates"), attribute.class("cancel-link")], [
          html.text("Cancel"),
        ]),
      ]),
    ],
  )
}

fn form_field(
  field_name: String,
  label_text: String,
  input_type: String,
  current_value: String,
  is_required: Bool,
  extra_attributes: List(attribute.Attribute(Nil)),
) -> Element(Nil) {
  let base_attributes = [
    attribute.type_(input_type),
    attribute.id(field_name),
    attribute.name(field_name),
    attribute.value(current_value),
    attribute.class("form-input"),
  ]
  let attributes = case is_required {
    True -> [attribute.attribute("required", ""), ..base_attributes]
    False -> base_attributes
  }

  html.div([attribute.class("form-group")], [
    html.label([attribute.for(field_name)], [html.text(label_text)]),
    html.input(list.append(attributes, extra_attributes)),
  ])
}

fn form_textarea(
  field_name: String,
  label_text: String,
  current_value: String,
  is_required: Bool,
  placeholder_text: String,
  row_count: Int,
) -> Element(Nil) {
  let base_attributes = [
    attribute.id(field_name),
    attribute.name(field_name),
    attribute.placeholder(placeholder_text),
    attribute.class("form-textarea"),
    attribute.attribute("rows", int.to_string(row_count)),
  ]
  let attributes = case is_required {
    True -> [attribute.attribute("required", ""), ..base_attributes]
    False -> base_attributes
  }

  html.div([attribute.class("form-group")], [
    html.label([attribute.for(field_name)], [html.text(label_text)]),
    html.textarea(attributes, current_value),
  ])
}

fn form_select(
  select_name: String,
  label_text: String,
  current_value: String,
  options: List(#(String, String)),
) -> Element(Nil) {
  html.div([attribute.class("form-group")], [
    html.label([attribute.for(select_name)], [html.text(label_text)]),
    html.select(
      [attribute.id(select_name), attribute.name(select_name)],
      list.map(options, fn(opt) {
        let #(option_value, option_label) = opt
        html.option(
          [
            attribute.value(option_value),
            attribute.selected(option_value == current_value),
          ],
          option_label,
        )
      }),
    ),
  ])
}

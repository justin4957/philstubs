import gleam/list
import gleeunit/should
import philstubs/core/citation_extractor
import philstubs/core/reference

pub fn extract_usc_citation_test() {
  let citations =
    citation_extractor.extract_citations(
      "This bill amends 42 U.S.C. 1983 to clarify enforcement.",
    )

  citations |> list.length |> should.not_equal(0)

  let usc_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.UscReference
    })
  usc_citations |> list.length |> should.not_equal(0)

  let assert Ok(first) = list.first(usc_citations)
  first.confidence |> should.equal(0.9)
}

pub fn extract_public_law_citation_test() {
  let citations =
    citation_extractor.extract_citations(
      "As established by Pub. L. 117-169, the Inflation Reduction Act.",
    )

  let pub_law_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.PublicLawReference
    })
  pub_law_citations |> list.length |> should.not_equal(0)

  let assert Ok(first) = list.first(pub_law_citations)
  first.confidence |> should.equal(0.9)
}

pub fn extract_public_law_full_text_test() {
  let citations =
    citation_extractor.extract_citations(
      "Pursuant to Public Law 110-343, the following provisions apply.",
    )

  let pub_law_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.PublicLawReference
    })
  pub_law_citations |> list.length |> should.not_equal(0)
}

pub fn extract_cfr_citation_test() {
  let citations =
    citation_extractor.extract_citations(
      "Compliance with 40 C.F.R. 98 is required for all facilities.",
    )

  let cfr_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.CfrReference
    })
  cfr_citations |> list.length |> should.not_equal(0)

  let assert Ok(first) = list.first(cfr_citations)
  first.confidence |> should.equal(0.9)
}

pub fn extract_bill_reference_test() {
  let citations =
    citation_extractor.extract_citations(
      "This legislation relates to H.R. 1234 and S. 567.",
    )

  let bill_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.BillReference
    })
  bill_citations |> list.length |> should.equal(2)

  let assert Ok(first) = list.first(bill_citations)
  first.confidence |> should.equal(0.8)
}

pub fn extract_section_reference_test() {
  let citations =
    citation_extractor.extract_citations(
      "As described in section 101 of this Act, the provisions shall apply.",
    )

  let section_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.SectionReference
    })
  section_citations |> list.length |> should.not_equal(0)

  let assert Ok(first) = list.first(section_citations)
  first.confidence |> should.equal(0.6)
}

pub fn extract_multiple_citations_test() {
  let text =
    "This bill amends 42 U.S.C. 1983 and 26 U.S.C. 501 "
    <> "in accordance with Pub. L. 117-169."

  let citations = citation_extractor.extract_citations(text)

  // Should find at least USC and Public Law citations
  let usc_count =
    list.count(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.UscReference
    })
  usc_count |> should.not_equal(0)

  let pub_law_count =
    list.count(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.PublicLawReference
    })
  pub_law_count |> should.not_equal(0)
}

pub fn extract_case_insensitive_test() {
  let citations_lower =
    citation_extractor.extract_citations("see 42 u.s.c. 1983")
  let citations_mixed =
    citation_extractor.extract_citations("see 42 U.S.C. 1983")

  // Both should extract citations
  citations_lower |> list.length |> should.not_equal(0)
  citations_mixed |> list.length |> should.not_equal(0)
}

pub fn extract_empty_text_returns_empty_test() {
  let citations = citation_extractor.extract_citations("")
  citations |> should.equal([])
}

pub fn extract_irrelevant_text_returns_empty_test() {
  let citations =
    citation_extractor.extract_citations(
      "The weather today is sunny with a high of 75 degrees.",
    )
  citations |> should.equal([])
}

pub fn infer_amends_reference_type_test() {
  let ref_type =
    citation_extractor.infer_reference_type(
      "This bill amends the existing statute",
    )
  ref_type |> should.equal(reference.Amends)
}

pub fn infer_supersedes_from_repeal_test() {
  let ref_type =
    citation_extractor.infer_reference_type(
      "The Act shall repeal the prior provisions",
    )
  ref_type |> should.equal(reference.Supersedes)
}

pub fn infer_implements_from_pursuant_test() {
  let ref_type =
    citation_extractor.infer_reference_type(
      "pursuant to the regulations established by",
    )
  ref_type |> should.equal(reference.Implements)
}

pub fn infer_delegates_reference_type_test() {
  let ref_type =
    citation_extractor.infer_reference_type(
      "The Secretary shall delegate authority under",
    )
  ref_type |> should.equal(reference.Delegates)
}

pub fn infer_default_references_type_test() {
  let ref_type =
    citation_extractor.infer_reference_type("as described in the following")
  ref_type |> should.equal(reference.References)
}

pub fn deduplicate_keeps_highest_confidence_test() {
  let citations = [
    citation_extractor.ExtractedCitation(
      citation_text: "42 u.s.c. 1983",
      citation_type: citation_extractor.UscReference,
      reference_type: reference.References,
      confidence: 0.6,
    ),
    citation_extractor.ExtractedCitation(
      citation_text: "42 u.s.c. 1983",
      citation_type: citation_extractor.UscReference,
      reference_type: reference.References,
      confidence: 0.9,
    ),
  ]

  let deduped = citation_extractor.deduplicate_citations(citations)
  deduped |> list.length |> should.equal(1)

  let assert Ok(first) = list.first(deduped)
  first.confidence |> should.equal(0.9)
}

pub fn citation_type_to_string_test() {
  citation_extractor.citation_type_to_string(citation_extractor.UscReference)
  |> should.equal("usc")
  citation_extractor.citation_type_to_string(
    citation_extractor.PublicLawReference,
  )
  |> should.equal("public_law")
  citation_extractor.citation_type_to_string(citation_extractor.CfrReference)
  |> should.equal("cfr")
  citation_extractor.citation_type_to_string(citation_extractor.BillReference)
  |> should.equal("bill")
  citation_extractor.citation_type_to_string(
    citation_extractor.SectionReference,
  )
  |> should.equal("section")
}

pub fn context_based_reference_type_extraction_test() {
  let citations =
    citation_extractor.extract_citations(
      "This bill amends 42 U.S.C. 1983 to expand civil rights protections.",
    )

  let usc_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.UscReference
    })

  case list.first(usc_citations) {
    Ok(citation) -> citation.reference_type |> should.equal(reference.Amends)
    Error(_) -> should.fail()
  }
}

pub fn joint_resolution_bill_reference_test() {
  let citations =
    citation_extractor.extract_citations(
      "See also H.J.Res. 89 for the proposed amendment.",
    )

  let bill_citations =
    list.filter(citations, fn(citation: citation_extractor.ExtractedCitation) {
      citation.citation_type == citation_extractor.BillReference
    })
  bill_citations |> list.length |> should.not_equal(0)
}

//
// Copyright RIME Developers
// Distributed under the BSD License
//
// 2014-03-31 Chongyu Zhu <i@lembacon.com>
//
#include <stdint.h>  // for uint32_t
#include <utf8.h>
#include <rime/candidate.h>
#include <rime/common.h>
#include <rime/context.h>
#include <rime/engine.h>
#include <rime/dict/vocabulary.h>
#include <rime/gear/charset_filter.h>

namespace rime {

bool contains_extended_cjk(const string& text) {
  const char* p = text.c_str();
  uint32_t ch;

  while ((ch = utf8::unchecked::next(p)) != 0) {
    if (is_extended_cjk(ch)) {
      return true;
    }
  }

  return false;
}

// CharsetFilterTranslation

CharsetFilterTranslation::CharsetFilterTranslation(an<Translation> translation)
    : translation_(translation) {
  LocateNextCandidate();
}

bool CharsetFilterTranslation::Next() {
  if (exhausted())
    return false;
  if (!translation_->Next()) {
    set_exhausted(true);
    return false;
  }
  return LocateNextCandidate();
}

an<Candidate> CharsetFilterTranslation::Peek() {
  return translation_->Peek();
}

bool CharsetFilterTranslation::FilterCandidate(an<Candidate> cand) {
  return CharsetFilter::FilterText(cand->text());
}

bool CharsetFilterTranslation::LocateNextCandidate() {
  while (!translation_->exhausted()) {
    auto cand = translation_->Peek();
    if (cand && FilterCandidate(cand))
      return true;
    translation_->Next();
  }
  set_exhausted(true);
  return false;
}

// CharsetFilter

bool CharsetFilter::FilterText(const string& text) {
  return !contains_extended_cjk(text);
}

bool CharsetFilter::FilterDictEntry(an<DictEntry> entry) {
  return entry && FilterText(entry->text);
}

CharsetFilter::CharsetFilter(const Ticket& ticket)
    : Filter(ticket), TagMatching(ticket) {}

an<Translation> CharsetFilter::Apply(an<Translation> translation,
                                     CandidateList* candidates) {
  if (name_space_.empty() &&
      !engine_->context()->get_option("extended_charset")) {
    return New<CharsetFilterTranslation>(translation);
  }
  if (!name_space_.empty()) {
    LOG(ERROR) << "charset parameter is unsupported by basic charset_filter";
  }
  return translation;
}

}  // namespace rime

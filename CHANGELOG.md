# Changelog

## 1.0.0+2

### Phase 1B.3: PDF/Document Intelligence

- Added bounded PDF structural validation and metadata inspection.
- Added local bounded text and URL extraction with reuse of the existing URL and text analyzers.
- Added indicators for JavaScript, launch actions, forms, annotations, and embedded content.
- Added encrypted and incomplete-document handling that never assigns a safe verdict.
- Added semantic LOW, CAUTION, HIGH, CRITICAL, and UNKNOWN risk signals.
- Kept submitted content temporary and quarantined during analysis, with cleanup after the first pass.

This release performs static first-pass inspection only. It does not provide dynamic execution, sandbox execution, ML analysis, live threat intelligence, APK analysis, or deep archive analysis. It does not claim complete malware detection.

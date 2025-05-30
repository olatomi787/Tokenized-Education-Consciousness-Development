;; Assessment Framework Contract
;; Evaluates consciousness development outcomes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-already-exists (err u302))
(define-constant err-invalid-score (err u303))
(define-constant err-not-authorized (err u304))

;; Data Variables
(define-data-var assessment-counter uint u0)
(define-data-var result-counter uint u0)

;; Data Maps
(define-map assessments
  { assessment-id: uint }
  {
    name: (string-ascii 100),
    program-id: uint,
    description: (string-ascii 500),
    max-score: uint,
    passing-score: uint,
    active: bool,
    created-by: principal,
    created-at: uint
  }
)

(define-map assessment-results
  { result-id: uint }
  {
    assessment-id: uint,
    student: principal,
    score: uint,
    passed: bool,
    completed-at: uint,
    evaluator: principal,
    feedback: (string-ascii 500)
  }
)

(define-map student-assessments
  { student: principal, assessment-id: uint }
  { result-id: uint }
)

(define-map certificates
  { certificate-id: uint }
  {
    student: principal,
    program-id: uint,
    assessment-id: uint,
    issued-at: uint,
    issuer: principal,
    certificate-hash: (buff 32)
  }
)

;; Public Functions

;; Create a new assessment
(define-public (create-assessment
  (name (string-ascii 100))
  (program-id uint)
  (description (string-ascii 500))
  (max-score uint)
  (passing-score uint)
)
  (let
    (
      (assessment-id (+ (var-get assessment-counter) u1))
    )
    (asserts! (<= passing-score max-score) err-invalid-score)
    (var-set assessment-counter assessment-id)

    (map-set assessments
      { assessment-id: assessment-id }
      {
        name: name,
        program-id: program-id,
        description: description,
        max-score: max-score,
        passing-score: passing-score,
        active: true,
        created-by: tx-sender,
        created-at: block-height
      }
    )
    (ok assessment-id)
  )
)

;; Submit assessment result
(define-public (submit-assessment-result
  (assessment-id uint)
  (student principal)
  (score uint)
  (feedback (string-ascii 500))
)
  (let
    (
      (result-id (+ (var-get result-counter) u1))
    )
    (match (map-get? assessments { assessment-id: assessment-id })
      assessment
      (begin
        (asserts! (get active assessment) err-not-found)
        (asserts! (<= score (get max-score assessment)) err-invalid-score)

        (var-set result-counter result-id)

        (let
          (
            (passed (>= score (get passing-score assessment)))
          )
          (map-set assessment-results
            { result-id: result-id }
            {
              assessment-id: assessment-id,
              student: student,
              score: score,
              passed: passed,
              completed-at: block-height,
              evaluator: tx-sender,
              feedback: feedback
            }
          )

          (map-set student-assessments
            { student: student, assessment-id: assessment-id }
            { result-id: result-id }
          )

          (ok result-id)
        )
      )
      err-not-found
    )
  )
)

;; Issue certificate
(define-public (issue-certificate
  (student principal)
  (program-id uint)
  (assessment-id uint)
  (certificate-hash (buff 32))
)
  (let
    (
      (certificate-id (+ (var-get result-counter) u1))
    )
    ;; Check if student passed the assessment
    (match (map-get? student-assessments { student: student, assessment-id: assessment-id })
      assessment-ref
      (match (map-get? assessment-results { result-id: (get result-id assessment-ref) })
        result
        (begin
          (asserts! (get passed result) err-not-authorized)

          (map-set certificates
            { certificate-id: certificate-id }
            {
              student: student,
              program-id: program-id,
              assessment-id: assessment-id,
              issued-at: block-height,
              issuer: tx-sender,
              certificate-hash: certificate-hash
            }
          )
          (ok certificate-id)
        )
        err-not-found
      )
      err-not-found
    )
  )
)

;; Read-only Functions

;; Get assessment details
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

;; Get assessment result
(define-read-only (get-assessment-result (result-id uint))
  (map-get? assessment-results { result-id: result-id })
)

;; Get student's assessment result
(define-read-only (get-student-result (student principal) (assessment-id uint))
  (match (map-get? student-assessments { student: student, assessment-id: assessment-id })
    assessment-ref
    (map-get? assessment-results { result-id: (get result-id assessment-ref) })
    none
  )
)

;; Check if student passed assessment
(define-read-only (did-student-pass (student principal) (assessment-id uint))
  (match (get-student-result student assessment-id)
    result (get passed result)
    false
  )
)

;; Get certificate
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates { certificate-id: certificate-id })
)

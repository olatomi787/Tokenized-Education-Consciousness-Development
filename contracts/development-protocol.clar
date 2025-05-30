;; Development Protocol Contract
;; Manages consciousness-enhancing education programs

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-enrolled (err u202))
(define-constant err-not-enrolled (err u203))
(define-constant err-program-full (err u204))
(define-constant err-not-verified-institution (err u205))

;; Data Variables
(define-data-var program-counter uint u0)
(define-data-var enrollment-counter uint u0)

;; Data Maps
(define-map programs
  { program-id: uint }
  {
    name: (string-ascii 100),
    institution-id: uint,
    description: (string-ascii 500),
    duration-blocks: uint,
    max-participants: uint,
    current-participants: uint,
    completion-reward: uint,
    active: bool,
    created-at: uint
  }
)

(define-map enrollments
  { enrollment-id: uint }
  {
    student: principal,
    program-id: uint,
    enrolled-at: uint,
    progress-percentage: uint,
    completed: bool,
    completion-date: uint,
    milestones-completed: uint
  }
)

(define-map student-programs
  { student: principal, program-id: uint }
  { enrollment-id: uint }
)

(define-map program-milestones
  { program-id: uint, milestone-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 300),
    required-for-completion: bool,
    reward-tokens: uint
  }
)

;; Public Functions

;; Create a new consciousness development program
(define-public (create-program
  (name (string-ascii 100))
  (institution-id uint)
  (description (string-ascii 500))
  (duration-blocks uint)
  (max-participants uint)
  (completion-reward uint)
)
  (let
    (
      (program-id (+ (var-get program-counter) u1))
    )
    ;; Verify institution is verified (would call institution-verification contract)
    (var-set program-counter program-id)

    (map-set programs
      { program-id: program-id }
      {
        name: name,
        institution-id: institution-id,
        description: description,
        duration-blocks: duration-blocks,
        max-participants: max-participants,
        current-participants: u0,
        completion-reward: completion-reward,
        active: true,
        created-at: block-height
      }
    )
    (ok program-id)
  )
)

;; Enroll in a consciousness development program
(define-public (enroll-in-program (program-id uint))
  (let
    (
      (enrollment-id (+ (var-get enrollment-counter) u1))
    )
    (match (map-get? programs { program-id: program-id })
      program
      (begin
        (asserts! (get active program) err-not-found)
        (asserts! (< (get current-participants program) (get max-participants program)) err-program-full)
        (asserts! (is-none (map-get? student-programs { student: tx-sender, program-id: program-id })) err-already-enrolled)

        (var-set enrollment-counter enrollment-id)

        (map-set enrollments
          { enrollment-id: enrollment-id }
          {
            student: tx-sender,
            program-id: program-id,
            enrolled-at: block-height,
            progress-percentage: u0,
            completed: false,
            completion-date: u0,
            milestones-completed: u0
          }
        )

        (map-set student-programs
          { student: tx-sender, program-id: program-id }
          { enrollment-id: enrollment-id }
        )

        ;; Update participant count
        (map-set programs
          { program-id: program-id }
          (merge program { current-participants: (+ (get current-participants program) u1) })
        )

        (ok enrollment-id)
      )
      err-not-found
    )
  )
)

;; Update student progress
(define-public (update-progress (enrollment-id uint) (progress-percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? enrollments { enrollment-id: enrollment-id })
      enrollment
      (begin
        (map-set enrollments
          { enrollment-id: enrollment-id }
          (merge enrollment { progress-percentage: progress-percentage })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Complete program
(define-public (complete-program (enrollment-id uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? enrollments { enrollment-id: enrollment-id })
      enrollment
      (begin
        (map-set enrollments
          { enrollment-id: enrollment-id }
          (merge enrollment {
            completed: true,
            completion-date: block-height,
            progress-percentage: u100
          })
        )
        (ok true)
      )
      err-not-found
    )
  )
)

;; Read-only Functions

;; Get program details
(define-read-only (get-program (program-id uint))
  (map-get? programs { program-id: program-id })
)

;; Get enrollment details
(define-read-only (get-enrollment (enrollment-id uint))
  (map-get? enrollments { enrollment-id: enrollment-id })
)

;; Get student's enrollment in a program
(define-read-only (get-student-enrollment (student principal) (program-id uint))
  (map-get? student-programs { student: student, program-id: program-id })
)

;; Check if student completed program
(define-read-only (is-program-completed (student principal) (program-id uint))
  (match (map-get? student-programs { student: student, program-id: program-id })
    enrollment-ref
    (match (map-get? enrollments { enrollment-id: (get enrollment-id enrollment-ref) })
      enrollment (get completed enrollment)
      false
    )
    false
  )
)

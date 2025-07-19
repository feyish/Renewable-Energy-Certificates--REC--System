;; Audit Verification Contract
;; Validates environmental claims and maintains audit trails

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-STATE (err u105))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map audit-records
  { audit-id: uint }
  {
    target-type: (string-ascii 20), ;; "generation", "certificate", "retirement"
    target-id: uint,
    auditor: principal,
    audit-date: uint,
    status: (string-ascii 20), ;; "pending", "approved", "rejected"
    findings: (string-ascii 500),
    compliance-score: uint, ;; 0-100
    verified: bool
  }
)

(define-map auditor-credentials
  { auditor: principal }
  {
    name: (string-ascii 100),
    certification: (string-ascii 100),
    authorized: bool,
    registration-date: uint,
    audit-count: uint
  }
)

(define-map audit-trail
  { target-type: (string-ascii 20), target-id: uint }
  {
    audit-ids: (list 50 uint),
    last-audit-date: uint,
    compliance-status: (string-ascii 20)
  }
)

(define-map environmental-claims
  { claim-id: uint }
  {
    claimant: principal,
    claim-type: (string-ascii 50),
    description: (string-ascii 500),
    supporting-data: (string-ascii 200),
    verified: bool,
    verification-date: (optional uint)
  }
)

;; Counters
(define-data-var next-audit-id uint u1)
(define-data-var next-claim-id uint u1)

;; Audit requirements
(define-data-var minimum-compliance-score uint u75)
(define-data-var audit-validity-period uint u52560) ;; ~1 year in blocks

;; Read-only functions
(define-read-only (get-audit-record (audit-id uint))
  (map-get? audit-records { audit-id: audit-id })
)

(define-read-only (get-auditor-credentials (auditor principal))
  (map-get? auditor-credentials { auditor: auditor })
)

(define-read-only (get-audit-trail (target-type (string-ascii 20)) (target-id uint))
  (default-to
    { audit-ids: (list), last-audit-date: u0, compliance-status: "unaudited" }
    (map-get? audit-trail { target-type: target-type, target-id: target-id })
  )
)

(define-read-only (get-environmental-claim (claim-id uint))
  (map-get? environmental-claims { claim-id: claim-id })
)

(define-read-only (is-authorized-auditor (auditor principal))
  (match (get-auditor-credentials auditor)
    credentials (get authorized credentials)
    false
  )
)

(define-read-only (get-minimum-compliance-score)
  (var-get minimum-compliance-score)
)

(define-read-only (is-audit-current (audit-date uint))
  (>= audit-date (- block-height (var-get audit-validity-period)))
)

;; Public functions
(define-public (register-auditor (name (string-ascii 100)) (certification (string-ascii 100)))
  (begin
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len certification) u0) ERR-INVALID-INPUT)
    (asserts! (is-none (get-auditor-credentials tx-sender)) ERR-ALREADY-EXISTS)

    (map-set auditor-credentials
      { auditor: tx-sender }
      {
        name: name,
        certification: certification,
        authorized: false,
        registration-date: block-height,
        audit-count: u0
      }
    )

    (ok true)
  )
)

(define-public (authorize-auditor (auditor principal))
  (let ((credentials (unwrap! (get-auditor-credentials auditor) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set auditor-credentials
      { auditor: auditor }
      (merge credentials { authorized: true })
    )

    (ok true)
  )
)

(define-public (conduct-audit (target-type (string-ascii 20)) (target-id uint) (findings (string-ascii 500)) (compliance-score uint))
  (let
    (
      (audit-id (var-get next-audit-id))
      (auditor-creds (unwrap! (get-auditor-credentials tx-sender) ERR-NOT-FOUND))
      (current-trail (get-audit-trail target-type target-id))
    )
    (asserts! (get authorized auditor-creds) ERR-NOT-AUTHORIZED)
    (asserts! (> (len target-type) u0) ERR-INVALID-INPUT)
    (asserts! (<= compliance-score u100) ERR-INVALID-INPUT)

    ;; Create audit record
    (map-set audit-records
      { audit-id: audit-id }
      {
        target-type: target-type,
        target-id: target-id,
        auditor: tx-sender,
        audit-date: block-height,
        status: (if (>= compliance-score (var-get minimum-compliance-score)) "approved" "rejected"),
        findings: findings,
        compliance-score: compliance-score,
        verified: false
      }
    )

    ;; Update audit trail
    (map-set audit-trail
      { target-type: target-type, target-id: target-id }
      {
        audit-ids: (unwrap-panic (as-max-len? (append (get audit-ids current-trail) audit-id) u50)),
        last-audit-date: block-height,
        compliance-status: (if (>= compliance-score (var-get minimum-compliance-score)) "compliant" "non-compliant")
      }
    )

    ;; Update auditor stats
    (map-set auditor-credentials
      { auditor: tx-sender }
      (merge auditor-creds { audit-count: (+ (get audit-count auditor-creds) u1) })
    )

    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

(define-public (verify-audit (audit-id uint))
  (let ((audit (unwrap! (get-audit-record audit-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (get verified audit)) ERR-INVALID-STATE)

    (map-set audit-records
      { audit-id: audit-id }
      (merge audit { verified: true })
    )

    (ok true)
  )
)

(define-public (submit-environmental-claim (claim-type (string-ascii 50)) (description (string-ascii 500)) (supporting-data (string-ascii 200)))
  (let ((claim-id (var-get next-claim-id)))
    (asserts! (> (len claim-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set environmental-claims
      { claim-id: claim-id }
      {
        claimant: tx-sender,
        claim-type: claim-type,
        description: description,
        supporting-data: supporting-data,
        verified: false,
        verification-date: none
      }
    )

    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (verify-environmental-claim (claim-id uint))
  (let ((claim (unwrap! (get-environmental-claim claim-id) ERR-NOT-FOUND)))
    (asserts! (is-authorized-auditor tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get verified claim)) ERR-INVALID-STATE)

    (map-set environmental-claims
      { claim-id: claim-id }
      (merge claim {
        verified: true,
        verification-date: (some block-height)
      })
    )

    (ok true)
  )
)

(define-public (update-compliance-requirements (new-minimum-score uint) (new-validity-period uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-minimum-score u100) ERR-INVALID-INPUT)
    (asserts! (> new-validity-period u0) ERR-INVALID-INPUT)

    (var-set minimum-compliance-score new-minimum-score)
    (var-set audit-validity-period new-validity-period)

    (ok true)
  )
)

(define-public (generate-compliance-report (target-type (string-ascii 20)) (target-id uint))
  (let
    (
      (trail (get-audit-trail target-type target-id))
      (latest-audit-id (match (element-at (get audit-ids trail) (- (len (get audit-ids trail)) u1))
        audit-id audit-id
        u0))
      (latest-audit (if (> latest-audit-id u0) (get-audit-record latest-audit-id) none))
    )
    (ok {
      target-type: target-type,
      target-id: target-id,
      compliance-status: (get compliance-status trail),
      last-audit-date: (get last-audit-date trail),
      audit-count: (len (get audit-ids trail)),
      current-audit: (is-audit-current (get last-audit-date trail)),
      latest-score: (match latest-audit audit (some (get compliance-score audit)) none),
      generated-at: block-height
    })
  )
)

(define-public (revoke-auditor-authorization (auditor principal))
  (let ((credentials (unwrap! (get-auditor-credentials auditor) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set auditor-credentials
      { auditor: auditor }
      (merge credentials { authorized: false })
    )

    (ok true)
  )
)

(define-public (challenge-audit (audit-id uint) (reason (string-ascii 200)))
  (let ((audit (unwrap! (get-audit-record audit-id) ERR-NOT-FOUND)))
    (asserts! (> (len reason) u0) ERR-INVALID-INPUT)
    (asserts! (get verified audit) ERR-INVALID-STATE)

    ;; Mark audit as challenged (would need additional data structure in full implementation)
    (ok true)
  )
)

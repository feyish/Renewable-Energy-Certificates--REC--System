;; Certificate Issuance Contract
;; Creates tradeable renewable energy credits linked to verified generation

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map certificates
  { certificate-id: uint }
  {
    generation-record-id: uint,
    amount: uint,
    energy-type: (string-ascii 20),
    issue-date: uint,
    owner: principal,
    retired: bool,
    vintage: uint
  }
)

(define-map certificate-ownership
  { owner: principal, certificate-id: uint }
  { amount: uint }
)

(define-map owner-certificates
  { owner: principal }
  { certificate-ids: (list 1000 uint) }
)

;; Counters
(define-data-var next-certificate-id uint u1)

;; Certificate status tracking
(define-map issued-for-generation uint bool)

;; Read-only functions
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates { certificate-id: certificate-id })
)

(define-read-only (get-certificate-ownership (owner principal) (certificate-id uint))
  (map-get? certificate-ownership { owner: owner, certificate-id: certificate-id })
)

(define-read-only (get-owner-certificates (owner principal))
  (default-to { certificate-ids: (list) } (map-get? owner-certificates { owner: owner }))
)

(define-read-only (is-generation-used (generation-record-id uint))
  (default-to false (map-get? issued-for-generation generation-record-id))
)

(define-read-only (get-next-certificate-id)
  (var-get next-certificate-id)
)

;; Public functions
(define-public (issue-certificate (generation-record-id uint) (amount uint) (energy-type (string-ascii 20)))
  (let ((certificate-id (var-get next-certificate-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (> (len energy-type) u0) ERR-INVALID-INPUT)
    (asserts! (not (is-generation-used generation-record-id)) ERR-ALREADY-EXISTS)

    (map-set certificates
      { certificate-id: certificate-id }
      {
        generation-record-id: generation-record-id,
        amount: amount,
        energy-type: energy-type,
        issue-date: block-height,
        owner: tx-sender,
        retired: false,
        vintage: block-height
      }
    )

    (map-set certificate-ownership
      { owner: tx-sender, certificate-id: certificate-id }
      { amount: amount }
    )

    (map-set issued-for-generation generation-record-id true)
    (var-set next-certificate-id (+ certificate-id u1))

    (ok certificate-id)
  )
)

(define-public (transfer-certificate (certificate-id uint) (recipient principal) (amount uint))
  (let
    (
      (certificate (unwrap! (get-certificate certificate-id) ERR-NOT-FOUND))
      (sender-ownership (unwrap! (get-certificate-ownership tx-sender certificate-id) ERR-NOT-FOUND))
      (sender-amount (get amount sender-ownership))
    )
    (asserts! (not (get retired certificate)) ERR-INVALID-INPUT)
    (asserts! (>= sender-amount amount) ERR-INVALID-INPUT)
    (asserts! (> amount u0) ERR-INVALID-INPUT)
    (asserts! (not (is-eq tx-sender recipient)) ERR-INVALID-INPUT)

    ;; Update sender ownership
    (if (is-eq sender-amount amount)
      (map-delete certificate-ownership { owner: tx-sender, certificate-id: certificate-id })
      (map-set certificate-ownership
        { owner: tx-sender, certificate-id: certificate-id }
        { amount: (- sender-amount amount) }
      )
    )

    ;; Update recipient ownership
    (let ((recipient-ownership (get-certificate-ownership recipient certificate-id)))
      (match recipient-ownership
        existing-ownership
        (map-set certificate-ownership
          { owner: recipient, certificate-id: certificate-id }
          { amount: (+ (get amount existing-ownership) amount) }
        )
        (map-set certificate-ownership
          { owner: recipient, certificate-id: certificate-id }
          { amount: amount }
        )
      )
    )

    ;; Update certificate owner if full transfer
    (if (is-eq sender-amount amount)
      (map-set certificates
        { certificate-id: certificate-id }
        (merge certificate { owner: recipient })
      )
      true
    )

    (ok true)
  )
)

(define-public (split-certificate (certificate-id uint) (split-amount uint))
  (let
    (
      (certificate (unwrap! (get-certificate certificate-id) ERR-NOT-FOUND))
      (ownership (unwrap! (get-certificate-ownership tx-sender certificate-id) ERR-NOT-FOUND))
      (owned-amount (get amount ownership))
      (new-certificate-id (var-get next-certificate-id))
    )
    (asserts! (not (get retired certificate)) ERR-INVALID-INPUT)
    (asserts! (> split-amount u0) ERR-INVALID-INPUT)
    (asserts! (< split-amount owned-amount) ERR-INVALID-INPUT)

    ;; Create new certificate for split amount
    (map-set certificates
      { certificate-id: new-certificate-id }
      (merge certificate {
        amount: split-amount,
        owner: tx-sender
      })
    )

    ;; Update original certificate ownership
    (map-set certificate-ownership
      { owner: tx-sender, certificate-id: certificate-id }
      { amount: (- owned-amount split-amount) }
    )

    ;; Set ownership for new certificate
    (map-set certificate-ownership
      { owner: tx-sender, certificate-id: new-certificate-id }
      { amount: split-amount }
    )

    (var-set next-certificate-id (+ new-certificate-id u1))
    (ok new-certificate-id)
  )
)

(define-public (batch-issue-certificates (generation-records (list 100 uint)) (amounts (list 100 uint)) (energy-types (list 100 (string-ascii 20))))
  (let ((results (map issue-single-certificate generation-records amounts energy-types)))
    (ok results)
  )
)

(define-private (issue-single-certificate (generation-record-id uint) (amount uint) (energy-type (string-ascii 20)))
  (issue-certificate generation-record-id amount energy-type)
)

(define-public (update-certificate-metadata (certificate-id uint) (new-energy-type (string-ascii 20)))
  (let ((certificate (unwrap! (get-certificate certificate-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-energy-type) u0) ERR-INVALID-INPUT)

    (map-set certificates
      { certificate-id: certificate-id }
      (merge certificate { energy-type: new-energy-type })
    )

    (ok true)
  )
)

;; ConsultPro: Professional consultation booking platform with expertise verification
;; Connects industry experts with clients seeking specialized advice

(define-data-var consultation-admin principal tx-sender)
(define-map consultant-profiles
  { consultant-id: uint }
  {
    advisor: principal,
    consultation-fee: uint,
    expertise-domain: (string-ascii 50),
    credentials-summary: (string-ascii 500),
    advisory-years: uint,
    certified: bool
  }
)

(define-map consultation-logs
  { consultant-id: uint, consultation-id: uint }
  {
    client: principal,
    appointment-time: uint,
    consultation-format: (string-ascii 20)
  }
)

(define-data-var next-consultant-id uint u1)
(define-map consultation-tracker 
  { consultant-id: uint }
  { consultations: uint }
)

;; Register as a consultant
(define-public (register-consultant (domain-input (string-ascii 50)) (credentials-input (string-ascii 500)) (years-input uint) (fee-input uint))
  (let
    (
      (consultant-id (var-get next-consultant-id))
      (consultation-id u0)
      (domain domain-input)
      (credentials credentials-input)
      (years years-input)
      (fee fee-input)
    )
    ;; Input validation
    (asserts! (> fee u0) (err u1))
    (asserts! (> (len domain) u0) (err u5))
    (asserts! (> (len credentials) u0) (err u6))
    (asserts! (> years u0) (err u7))
    
    (map-set consultant-profiles
      { consultant-id: consultant-id }
      {
        advisor: tx-sender,
        consultation-fee: fee,
        expertise-domain: domain,
        credentials-summary: credentials,
        advisory-years: years,
        certified: false
      }
    )
    (map-set consultation-logs
      { consultant-id: consultant-id, consultation-id: consultation-id }
      {
        client: tx-sender,
        appointment-time: consultant-id,
        consultation-format: "registered"
      }
    )
    (map-set consultation-tracker 
      { consultant-id: consultant-id }
      { consultations: u1 }
    )
    (var-set next-consultant-id (+ consultant-id u1))
    (ok consultant-id)
  )
)

;; Book a consultation
(define-public (book-consultation (consultant-id-input uint))
  (let
    (
      (consultant-id consultant-id-input)
      (consultant-info (unwrap! (map-get? consultant-profiles { consultant-id: consultant-id }) (err u2)))
      (fee (get consultation-fee consultant-info))
      (advisor (get advisor consultant-info))
      (consultation-data (default-to { consultations: u0 } (map-get? consultation-tracker { consultant-id: consultant-id })))
      (consultation-id (get consultations consultation-data))
      (new-consultation-id (+ consultation-id u1))
    )
    ;; Input validation
    (asserts! (> consultant-id u0) (err u8))
    (asserts! (not (is-eq tx-sender advisor)) (err u3))
    
    (try! (stx-transfer? fee tx-sender advisor))
    (map-set consultation-logs
      { consultant-id: consultant-id, consultation-id: consultation-id }
      {
        client: tx-sender,
        appointment-time: (var-get next-consultant-id),
        consultation-format: "booked"
      }
    )
    (map-set consultation-tracker 
      { consultant-id: consultant-id }
      { consultations: new-consultation-id }
    )
    (ok true)
  )
)

;; Certify a consultant (admin only)
(define-public (certify-consultant (consultant-id-input uint))
  (let
    (
      (consultant-id consultant-id-input)
      (consultant-info (unwrap! (map-get? consultant-profiles { consultant-id: consultant-id }) (err u2)))
      (consultation-data (default-to { consultations: u0 } (map-get? consultation-tracker { consultant-id: consultant-id })))
      (consultation-id (get consultations consultation-data))
      (new-consultation-id (+ consultation-id u1))
    )
    ;; Input validation
    (asserts! (> consultant-id u0) (err u8))
    (asserts! (is-eq tx-sender (var-get consultation-admin)) (err u4))
    
    (map-set consultant-profiles
      { consultant-id: consultant-id }
      (merge consultant-info { certified: true })
    )
    (map-set consultation-logs
      { consultant-id: consultant-id, consultation-id: consultation-id }
      {
        client: (get advisor consultant-info),
        appointment-time: (var-get next-consultant-id),
        consultation-format: "certified"
      }
    )
    (map-set consultation-tracker 
      { consultant-id: consultant-id }
      { consultations: new-consultation-id }
    )
    (ok true)
  )
)

;; Get consultant profile
(define-read-only (get-consultant (consultant-id uint))
  (map-get? consultant-profiles { consultant-id: consultant-id })
)

;; Get consultation log entry
(define-read-only (get-consultation-record (consultant-id uint) (consultation-id uint))
  (map-get? consultation-logs { consultant-id: consultant-id, consultation-id: consultation-id })
)

;; Get total consultations for a consultant
(define-read-only (get-consultation-count (consultant-id uint))
  (let
    (
      (consultation-data (default-to { consultations: u0 } (map-get? consultation-tracker { consultant-id: consultant-id })))
    )
    (get consultations consultation-data)
  )
)

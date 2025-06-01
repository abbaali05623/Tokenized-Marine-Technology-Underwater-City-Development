;; Development Entity Verification Contract
;; Validates underwater city development entities

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ENTITY_NOT_FOUND (err u101))
(define-constant ERR_ENTITY_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Entity verification status
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)
(define-constant STATUS_SUSPENDED u3)

;; Data structures
(define-map verified-entities
  { entity-id: uint }
  {
    entity-name: (string-ascii 100),
    entity-address: principal,
    verification-status: uint,
    verification-date: uint,
    certifications: (list 10 (string-ascii 50)),
    experience-years: uint
  }
)

(define-map entity-projects
  { entity-id: uint }
  { project-count: uint, active-projects: (list 20 uint) }
)

(define-data-var next-entity-id uint u1)

;; Public functions
(define-public (register-entity
  (entity-name (string-ascii 100))
  (certifications (list 10 (string-ascii 50)))
  (experience-years uint))
  (let ((entity-id (var-get next-entity-id)))
    (asserts! (is-none (map-get? verified-entities { entity-id: entity-id })) ERR_ENTITY_ALREADY_EXISTS)
    (map-set verified-entities
      { entity-id: entity-id }
      {
        entity-name: entity-name,
        entity-address: tx-sender,
        verification-status: STATUS_PENDING,
        verification-date: block-height,
        certifications: certifications,
        experience-years: experience-years
      }
    )
    (map-set entity-projects
      { entity-id: entity-id }
      { project-count: u0, active-projects: (list) }
    )
    (var-set next-entity-id (+ entity-id u1))
    (ok entity-id)
  )
)

(define-public (verify-entity (entity-id uint) (status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= status STATUS_SUSPENDED) ERR_INVALID_STATUS)
    (match (map-get? verified-entities { entity-id: entity-id })
      entity-data (begin
        (map-set verified-entities
          { entity-id: entity-id }
          (merge entity-data { verification-status: status, verification-date: block-height })
        )
        (ok true)
      )
      ERR_ENTITY_NOT_FOUND
    )
  )
)

(define-public (add-project-to-entity (entity-id uint) (project-id uint))
  (match (map-get? entity-projects { entity-id: entity-id })
    project-data (begin
      (map-set entity-projects
        { entity-id: entity-id }
        {
          project-count: (+ (get project-count project-data) u1),
          active-projects: (unwrap-panic (as-max-len? (append (get active-projects project-data) project-id) u20))
        }
      )
      (ok true)
    )
    ERR_ENTITY_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-entity-info (entity-id uint))
  (map-get? verified-entities { entity-id: entity-id })
)

(define-read-only (get-entity-projects (entity-id uint))
  (map-get? entity-projects { entity-id: entity-id })
)

(define-read-only (is-entity-verified (entity-id uint))
  (match (map-get? verified-entities { entity-id: entity-id })
    entity-data (is-eq (get verification-status entity-data) STATUS_VERIFIED)
    false
  )
)

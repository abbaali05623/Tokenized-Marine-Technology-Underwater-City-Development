;; Construction Protocol Contract
;; Manages underwater city construction phases and protocols

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROJECT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PHASE (err u202))
(define-constant ERR_INSUFFICIENT_FUNDS (err u203))
(define-constant ERR_PHASE_NOT_READY (err u204))

;; Construction phases
(define-constant PHASE_PLANNING u0)
(define-constant PHASE_FOUNDATION u1)
(define-constant PHASE_STRUCTURE u2)
(define-constant PHASE_SYSTEMS u3)
(define-constant PHASE_TESTING u4)
(define-constant PHASE_COMPLETED u5)

;; Data structures
(define-map construction-projects
  { project-id: uint }
  {
    project-name: (string-ascii 100),
    developer-entity: uint,
    current-phase: uint,
    depth-meters: uint,
    area-sqm: uint,
    budget-allocated: uint,
    budget-spent: uint,
    start-date: uint,
    estimated-completion: uint,
    safety-protocols: (list 10 (string-ascii 50))
  }
)

(define-map phase-requirements
  { project-id: uint, phase: uint }
  {
    requirements-met: bool,
    inspection-passed: bool,
    budget-approved: uint,
    completion-date: uint
  }
)

(define-data-var next-project-id uint u1)

;; Public functions
(define-public (create-construction-project
  (project-name (string-ascii 100))
  (developer-entity uint)
  (depth-meters uint)
  (area-sqm uint)
  (budget-allocated uint)
  (estimated-completion uint)
  (safety-protocols (list 10 (string-ascii 50))))
  (let ((project-id (var-get next-project-id)))
    (map-set construction-projects
      { project-id: project-id }
      {
        project-name: project-name,
        developer-entity: developer-entity,
        current-phase: PHASE_PLANNING,
        depth-meters: depth-meters,
        area-sqm: area-sqm,
        budget-allocated: budget-allocated,
        budget-spent: u0,
        start-date: block-height,
        estimated-completion: estimated-completion,
        safety-protocols: safety-protocols
      }
    )
    (var-set next-project-id (+ project-id u1))
    (ok project-id)
  )
)

(define-public (advance-construction-phase (project-id uint))
  (match (map-get? construction-projects { project-id: project-id })
    project-data (begin
      (asserts! (< (get current-phase project-data) PHASE_COMPLETED) ERR_INVALID_PHASE)
      (let ((next-phase (+ (get current-phase project-data) u1)))
        (map-set construction-projects
          { project-id: project-id }
          (merge project-data { current-phase: next-phase })
        )
        (ok next-phase)
      )
    )
    ERR_PROJECT_NOT_FOUND
  )
)

(define-public (approve-phase-completion
  (project-id uint)
  (phase uint)
  (budget-used uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set phase-requirements
      { project-id: project-id, phase: phase }
      {
        requirements-met: true,
        inspection-passed: true,
        budget-approved: budget-used,
        completion-date: block-height
      }
    )
    (ok true)
  )
)

(define-public (update-project-budget (project-id uint) (additional-spent uint))
  (match (map-get? construction-projects { project-id: project-id })
    project-data (begin
      (let ((new-spent (+ (get budget-spent project-data) additional-spent)))
        (asserts! (<= new-spent (get budget-allocated project-data)) ERR_INSUFFICIENT_FUNDS)
        (map-set construction-projects
          { project-id: project-id }
          (merge project-data { budget-spent: new-spent })
        )
        (ok new-spent)
      )
    )
    ERR_PROJECT_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-project-info (project-id uint))
  (map-get? construction-projects { project-id: project-id })
)

(define-read-only (get-phase-status (project-id uint) (phase uint))
  (map-get? phase-requirements { project-id: project-id, phase: phase })
)

(define-read-only (get-project-progress (project-id uint))
  (match (map-get? construction-projects { project-id: project-id })
    project-data (some {
      current-phase: (get current-phase project-data),
      progress-percentage: (* (get current-phase project-data) u20),
      budget-utilization: (/ (* (get budget-spent project-data) u100) (get budget-allocated project-data))
    })
    none
  )
)

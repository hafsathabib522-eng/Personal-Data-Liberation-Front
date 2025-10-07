;; Privacy Dashboard Contract
;; Central hub for managing privacy settings across multiple services
;; Handles privacy monitoring, compliance tracking, and violation detection

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-already-exists (err u203))
(define-constant err-invalid-privacy-level (err u204))
(define-constant err-compliance-failed (err u205))
(define-constant err-service-not-connected (err u206))
(define-constant err-invalid-setting (err u207))

;; Data Maps and Variables
(define-map registered-services
    { service-id: uint }
    {
        name: (string-ascii 100),
        website: (string-ascii 200),
        privacy-api-endpoint: (string-ascii 200),
        supported-settings: (list 30 (string-ascii 50)),
        compliance-standards: (list 10 (string-ascii 20)),
        data-categories: (list 20 (string-ascii 50)),
        active: bool,
        user-count: uint,
        privacy-score: uint
    }
)

(define-map user-service-connections
    { user-id: principal, service-id: uint }
    {
        connection-date: uint,
        auth-credentials-hash: (buff 32),
        current-privacy-settings: (list 30 { setting: (string-ascii 50), value: (string-ascii 100) }),
        last-sync: uint,
        monitoring-enabled: bool,
        status: (string-ascii 20),
        compliance-status: (string-ascii 20)
    }
)

(define-map privacy-profiles
    { user-id: principal }
    {
        profile-name: (string-ascii 100),
        privacy-level: uint,
        data-minimization: bool,
        tracking-protection: bool,
        advertising-preferences: (string-ascii 50),
        location-sharing: bool,
        communication-settings: (list 10 (string-ascii 50)),
        created-date: uint,
        last-updated: uint
    }
)

(define-map privacy-violations
    { violation-id: uint }
    {
        user-id: principal,
        service-id: uint,
        violation-type: (string-ascii 100),
        description: (string-ascii 500),
        severity-level: uint,
        detected-date: uint,
        status: (string-ascii 20),
        resolution: (optional (string-ascii 300)),
        evidence-hash: (buff 32)
    }
)

(define-map compliance-reports
    { report-id: uint }
    {
        user-id: principal,
        service-id: uint,
        compliance-standard: (string-ascii 20),
        report-date: uint,
        compliance-score: uint,
        violations-found: uint,
        recommendations: (list 10 (string-ascii 200)),
        status: (string-ascii 20),
        next-review-date: uint
    }
)

(define-map privacy-recommendations
    { recommendation-id: uint }
    {
        user-id: principal,
        recommendation-type: (string-ascii 100),
        title: (string-ascii 200),
        description: (string-ascii 500),
        priority: uint,
        service-ids: (list 10 uint),
        implementation-steps: (list 5 (string-ascii 300)),
        created-date: uint,
        status: (string-ascii 20)
    }
)

(define-map data-collection-monitoring
    { monitoring-id: uint }
    {
        user-id: principal,
        service-id: uint,
        data-type: (string-ascii 50),
        collection-frequency: (string-ascii 20),
        purpose: (string-ascii 200),
        retention-period: uint,
        sharing-enabled: bool,
        monitoring-date: uint,
        consent-status: (string-ascii 20)
    }
)

(define-map privacy-analytics
    { user-id: principal, period: uint }
    {
        services-monitored: uint,
        violations-detected: uint,
        settings-optimized: uint,
        privacy-score-average: uint,
        data-requests-blocked: uint,
        compliance-percentage: uint
    }
)

;; Data Variables
(define-data-var next-service-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var next-report-id uint u1)
(define-data-var next-recommendation-id uint u1)
(define-data-var next-monitoring-id uint u1)
(define-data-var total-users uint u0)
(define-data-var system-active bool true)

;; Private Functions

(define-private (is-owner (sender principal))
    (is-eq sender contract-owner)
)

(define-private (is-service-registered (service-id uint))
    (match (map-get? registered-services { service-id: service-id })
        service-data (get active service-data)
        false
    )
)

(define-private (is-user-connected (user-id principal) (service-id uint))
    (match (map-get? user-service-connections { user-id: user-id, service-id: service-id })
        connection-data (is-eq (get status connection-data) "active")
        false
    )
)

(define-private (calculate-privacy-score (privacy-level uint) (tracking-protection bool) (data-minimization bool))
    (let (
        (base-score (* privacy-level u10))
        (tracking-bonus (if tracking-protection u10 u0))
        (minimization-bonus (if data-minimization u10 u0))
    )
        (if (<= (+ base-score tracking-bonus minimization-bonus) u100)
            (+ base-score tracking-bonus minimization-bonus)
            u100
        )
    )
)

(define-private (assess-compliance (service-id uint) (user-settings (list 30 { setting: (string-ascii 50), value: (string-ascii 100) })))
    (let (
        (service-data (unwrap-panic (map-get? registered-services { service-id: service-id })))
        (compliance-standards (get compliance-standards service-data))
    )
        ;; Simplified compliance assessment - in real implementation would check against actual standards
        (if (>= (len user-settings) u5)
            u85  ;; Good compliance
            (if (>= (len user-settings) u3)
                u65  ;; Moderate compliance
                u35  ;; Poor compliance
            )
        )
    )
)

(define-private (generate-recommendations (user-id principal) (privacy-score uint))
    (let (
        (recommendation-id (var-get next-recommendation-id))
    )
        (if (< privacy-score u60)
            (begin
                (map-set privacy-recommendations
                    { recommendation-id: recommendation-id }
                    {
                        user-id: user-id,
                        recommendation-type: "privacy-enhancement",
                        title: "Improve Privacy Settings",
                        description: "Your privacy score is below recommended levels. Consider enabling additional privacy protections.",
                        priority: u8,
                        service-ids: (list),
                        implementation-steps: (list "Enable tracking protection" "Review data sharing settings" "Update privacy preferences"),
                        created-date: stacks-block-height,
                        status: "active"
                    }
                )
                (var-set next-recommendation-id (+ recommendation-id u1))
                recommendation-id
            )
            u0
        )
    )
)

;; Public Functions

;; Initialize the system
(define-public (initialize)
    (begin
        (asserts! (is-owner tx-sender) err-owner-only)
        (var-set system-active true)
        (ok "Privacy Dashboard System initialized successfully")
    )
)

;; Register a new privacy-enabled service
(define-public (register-service
    (name (string-ascii 100))
    (website (string-ascii 200))
    (privacy-api-endpoint (string-ascii 200))
    (supported-settings (list 30 (string-ascii 50)))
    (compliance-standards (list 10 (string-ascii 20)))
    (data-categories (list 20 (string-ascii 50)))
)
    (let (
        (service-id (var-get next-service-id))
    )
        (asserts! (is-owner tx-sender) err-owner-only)
        (asserts! (var-get system-active) err-unauthorized)
        
        (map-set registered-services
            { service-id: service-id }
            {
                name: name,
                website: website,
                privacy-api-endpoint: privacy-api-endpoint,
                supported-settings: supported-settings,
                compliance-standards: compliance-standards,
                data-categories: data-categories,
                active: true,
                user-count: u0,
                privacy-score: u50
            }
        )
        
        (var-set next-service-id (+ service-id u1))
        (ok service-id)
    )
)

;; Create user privacy profile
(define-public (create-privacy-profile
    (profile-name (string-ascii 100))
    (privacy-level uint)
    (data-minimization bool)
    (tracking-protection bool)
    (advertising-preferences (string-ascii 50))
    (location-sharing bool)
    (communication-settings (list 10 (string-ascii 50)))
)
    (let (
        (user-id tx-sender)
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (and (>= privacy-level u1) (<= privacy-level u10)) err-invalid-privacy-level)
        (asserts! (is-none (map-get? privacy-profiles { user-id: user-id })) err-already-exists)
        
        (map-set privacy-profiles
            { user-id: user-id }
            {
                profile-name: profile-name,
                privacy-level: privacy-level,
                data-minimization: data-minimization,
                tracking-protection: tracking-protection,
                advertising-preferences: advertising-preferences,
                location-sharing: location-sharing,
                communication-settings: communication-settings,
                created-date: stacks-block-height,
                last-updated: stacks-block-height
            }
        )
        
        (var-set total-users (+ (var-get total-users) u1))
        (ok "Privacy profile created successfully")
    )
)

;; Connect to a service for privacy management
(define-public (connect-service
    (service-id uint)
    (auth-credentials-hash (buff 32))
    (initial-settings (list 30 { setting: (string-ascii 50), value: (string-ascii 100) }))
)
    (let (
        (user-id tx-sender)
        (service-data (unwrap! (map-get? registered-services { service-id: service-id }) err-not-found))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-service-registered service-id) err-not-found)
        (asserts! (is-some (map-get? privacy-profiles { user-id: user-id })) err-unauthorized)
        (asserts! (is-none (map-get? user-service-connections { user-id: user-id, service-id: service-id })) err-already-exists)
        
        (map-set user-service-connections
            { user-id: user-id, service-id: service-id }
            {
                connection-date: stacks-block-height,
                auth-credentials-hash: auth-credentials-hash,
                current-privacy-settings: initial-settings,
                last-sync: stacks-block-height,
                monitoring-enabled: true,
                status: "active",
                compliance-status: "pending"
            }
        )
        
        ;; Update service user count
        (map-set registered-services
            { service-id: service-id }
            (merge service-data {
                user-count: (+ (get user-count service-data) u1)
            })
        )
        
        (ok "Service connected successfully")
    )
)

;; Update privacy settings for a service
(define-public (update-privacy-settings
    (service-id uint)
    (new-settings (list 30 { setting: (string-ascii 50), value: (string-ascii 100) }))
)
    (let (
        (user-id tx-sender)
        (connection-data (unwrap! (map-get? user-service-connections { user-id: user-id, service-id: service-id }) err-not-found))
        (compliance-score (assess-compliance service-id new-settings))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-user-connected user-id service-id) err-service-not-connected)
        
        (map-set user-service-connections
            { user-id: user-id, service-id: service-id }
            (merge connection-data {
                current-privacy-settings: new-settings,
                last-sync: stacks-block-height,
                compliance-status: (if (> compliance-score u70) "compliant" "non-compliant")
            })
        )
        
        (ok "Privacy settings updated successfully")
    )
)

;; Report a privacy violation
(define-public (report-violation
    (service-id uint)
    (violation-type (string-ascii 100))
    (description (string-ascii 500))
    (severity-level uint)
    (evidence-hash (buff 32))
)
    (let (
        (user-id tx-sender)
        (violation-id (var-get next-violation-id))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-user-connected user-id service-id) err-service-not-connected)
        (asserts! (and (>= severity-level u1) (<= severity-level u10)) err-invalid-setting)
        
        (map-set privacy-violations
            { violation-id: violation-id }
            {
                user-id: user-id,
                service-id: service-id,
                violation-type: violation-type,
                description: description,
                severity-level: severity-level,
                detected-date: stacks-block-height,
                status: "reported",
                resolution: none,
                evidence-hash: evidence-hash
            }
        )
        
        (var-set next-violation-id (+ violation-id u1))
        (ok violation-id)
    )
)

;; Generate compliance report
(define-public (generate-compliance-report
    (service-id uint)
    (compliance-standard (string-ascii 20))
)
    (let (
        (user-id tx-sender)
        (report-id (var-get next-report-id))
        (connection-data (unwrap! (map-get? user-service-connections { user-id: user-id, service-id: service-id }) err-not-found))
        (compliance-score (assess-compliance service-id (get current-privacy-settings connection-data)))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-user-connected user-id service-id) err-service-not-connected)
        
        (map-set compliance-reports
            { report-id: report-id }
            {
                user-id: user-id,
                service-id: service-id,
                compliance-standard: compliance-standard,
                report-date: stacks-block-height,
                compliance-score: compliance-score,
                violations-found: u0, ;; Would be calculated based on actual violations
                recommendations: (list "Enable two-factor authentication" "Review data sharing policies"),
                status: "completed",
                next-review-date: (+ stacks-block-height u4320) ;; ~1 month
            }
        )
        
        (var-set next-report-id (+ report-id u1))
        (ok report-id)
    )
)

;; Monitor data collection activities
(define-public (monitor-data-collection
    (service-id uint)
    (data-type (string-ascii 50))
    (collection-frequency (string-ascii 20))
    (purpose (string-ascii 200))
    (retention-period uint)
    (sharing-enabled bool)
    (consent-status (string-ascii 20))
)
    (let (
        (user-id tx-sender)
        (monitoring-id (var-get next-monitoring-id))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-user-connected user-id service-id) err-service-not-connected)
        
        (map-set data-collection-monitoring
            { monitoring-id: monitoring-id }
            {
                user-id: user-id,
                service-id: service-id,
                data-type: data-type,
                collection-frequency: collection-frequency,
                purpose: purpose,
                retention-period: retention-period,
                sharing-enabled: sharing-enabled,
                monitoring-date: stacks-block-height,
                consent-status: consent-status
            }
        )
        
        (var-set next-monitoring-id (+ monitoring-id u1))
        (ok monitoring-id)
    )
)

;; Read-only Functions

;; Get service information
(define-read-only (get-service (service-id uint))
    (map-get? registered-services { service-id: service-id })
)

;; Get user privacy profile
(define-read-only (get-privacy-profile (user-id principal))
    (map-get? privacy-profiles { user-id: user-id })
)

;; Get user service connection
(define-read-only (get-service-connection (user-id principal) (service-id uint))
    (map-get? user-service-connections { user-id: user-id, service-id: service-id })
)

;; Get privacy violation details
(define-read-only (get-violation (violation-id uint))
    (map-get? privacy-violations { violation-id: violation-id })
)

;; Get compliance report
(define-read-only (get-compliance-report (report-id uint))
    (map-get? compliance-reports { report-id: report-id })
)

;; Get privacy recommendation
(define-read-only (get-recommendation (recommendation-id uint))
    (map-get? privacy-recommendations { recommendation-id: recommendation-id })
)

;; Get data collection monitoring record
(define-read-only (get-monitoring-record (monitoring-id uint))
    (map-get? data-collection-monitoring { monitoring-id: monitoring-id })
)

;; Get privacy analytics for user
(define-read-only (get-privacy-analytics (user-id principal) (period uint))
    (map-get? privacy-analytics { user-id: user-id, period: period })
)

;; Calculate user's overall privacy score
(define-read-only (calculate-user-privacy-score (user-id principal))
    (match (map-get? privacy-profiles { user-id: user-id })
        profile-data (calculate-privacy-score 
            (get privacy-level profile-data)
            (get tracking-protection profile-data)
            (get data-minimization profile-data)
        )
        u0
    )
)

;; Get system statistics
(define-read-only (get-system-stats)
    {
        next-service-id: (var-get next-service-id),
        next-violation-id: (var-get next-violation-id),
        next-report-id: (var-get next-report-id),
        total-users: (var-get total-users),
        system-active: (var-get system-active)
    }
)

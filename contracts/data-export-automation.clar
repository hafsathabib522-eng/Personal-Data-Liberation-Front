;; Data Export Automation Contract
;; Automated tools for downloading personal data from major platforms
;; Manages platform registration, export scheduling, and data verification

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-platform (err u104))
(define-constant err-export-failed (err u105))
(define-constant err-invalid-schedule (err u106))
(define-constant err-platform-not-connected (err u107))

;; Data Maps and Variables
(define-map registered-platforms
    { platform-id: uint }
    {
        name: (string-ascii 100),
        api-endpoint: (string-ascii 200),
        supported-data-types: (list 20 (string-ascii 50)),
        authentication-method: (string-ascii 50),
        rate-limit: uint,
        active: bool,
        total-users: uint,
        successful-exports: uint
    }
)

(define-map user-platform-connections
    { user-id: principal, platform-id: uint }
    {
        connection-date: uint,
        auth-token-hash: (buff 32),
        permissions: (list 10 (string-ascii 50)),
        last-export: (optional uint),
        export-count: uint,
        status: (string-ascii 20),
        data-types-enabled: (list 20 (string-ascii 50))
    }
)

(define-map export-jobs
    { job-id: uint }
    {
        user-id: principal,
        platform-id: uint,
        data-types: (list 20 (string-ascii 50)),
        schedule-type: (string-ascii 20),
        frequency: uint,
        next-execution: uint,
        status: (string-ascii 20),
        created-at: uint,
        last-execution: (optional uint),
        output-format: (string-ascii 20),
        storage-location: (string-ascii 200)
    }
)

(define-map export-executions
    { execution-id: uint }
    {
        job-id: uint,
        execution-date: uint,
        status: (string-ascii 20),
        data-size: uint,
        verification-hash: (buff 32),
        error-message: (optional (string-ascii 500)),
        completion-time: uint,
        files-exported: (list 50 (string-ascii 100))
    }
)

(define-map data-verification
    { verification-id: uint }
    {
        execution-id: uint,
        original-hash: (buff 32),
        verification-hash: (buff 32),
        verification-date: uint,
        status: (string-ascii 20),
        verifier: principal,
        integrity-score: uint
    }
)

(define-map user-preferences
    { user-id: principal }
    {
        default-format: (string-ascii 20),
        encryption-enabled: bool,
        notification-settings: (list 5 (string-ascii 30)),
        storage-preference: (string-ascii 50),
        data-retention-period: uint,
        privacy-level: uint
    }
)

(define-map platform-analytics
    { platform-id: uint, period: uint }
    {
        total-exports: uint,
        successful-exports: uint,
        failed-exports: uint,
        average-data-size: uint,
        user-count: uint,
        uptime-percentage: uint
    }
)

;; Data Variables
(define-data-var next-platform-id uint u1)
(define-data-var next-job-id uint u1)
(define-data-var next-execution-id uint u1)
(define-data-var next-verification-id uint u1)
(define-data-var total-users uint u0)
(define-data-var system-active bool true)

;; Private Functions

(define-private (is-owner (sender principal))
    (is-eq sender contract-owner)
)

(define-private (is-platform-registered (platform-id uint))
    (match (map-get? registered-platforms { platform-id: platform-id })
        platform-data (get active platform-data)
        false
    )
)

(define-private (is-user-connected (user-id principal) (platform-id uint))
    (match (map-get? user-platform-connections { user-id: user-id, platform-id: platform-id })
        connection-data (is-eq (get status connection-data) "active")
        false
    )
)

(define-private (calculate-next-execution (frequency uint) (schedule-type (string-ascii 20)))
    (let (
        (current-time stacks-block-height)
    )
        (if (is-eq schedule-type "daily")
            (+ current-time (* frequency u144)) ;; Assuming ~10 minute blocks, 144 blocks = ~1 day
            (if (is-eq schedule-type "weekly")
                (+ current-time (* frequency u1008)) ;; ~1 week
                (if (is-eq schedule-type "monthly")
                    (+ current-time (* frequency u4320)) ;; ~1 month
                    (+ current-time frequency) ;; Custom interval
                )
            )
        )
    )
)

(define-private (generate-verification-hash (execution-id uint) (data-size uint))
    (keccak256 (concat 
        (unwrap-panic (to-consensus-buff? execution-id))
        (unwrap-panic (to-consensus-buff? data-size))
    ))
)

(define-private (update-platform-analytics (platform-id uint) (export-successful bool) (data-size uint))
    (let (
        (current-period (/ stacks-block-height u4320)) ;; Monthly periods
        (current-stats (default-to 
            { total-exports: u0, successful-exports: u0, failed-exports: u0,
              average-data-size: u0, user-count: u0, uptime-percentage: u100 }
            (map-get? platform-analytics { platform-id: platform-id, period: current-period })
        ))
        (new-stats (merge current-stats {
            total-exports: (+ (get total-exports current-stats) u1),
            successful-exports: (if export-successful 
                (+ (get successful-exports current-stats) u1)
                (get successful-exports current-stats)
            ),
            failed-exports: (if export-successful
                (get failed-exports current-stats)
                (+ (get failed-exports current-stats) u1)
            ),
            average-data-size: (/ (+ (* (get average-data-size current-stats) (get total-exports current-stats)) data-size)
                                 (+ (get total-exports current-stats) u1))
        }))
    )
        (map-set platform-analytics
            { platform-id: platform-id, period: current-period }
            new-stats
        )
    )
)

;; Public Functions

;; Initialize the system
(define-public (initialize)
    (begin
        (asserts! (is-owner tx-sender) err-owner-only)
        (var-set system-active true)
        (ok "Data Export Automation System initialized successfully")
    )
)

;; Register a new data export platform
(define-public (register-platform
    (name (string-ascii 100))
    (api-endpoint (string-ascii 200))
    (supported-data-types (list 20 (string-ascii 50)))
    (authentication-method (string-ascii 50))
    (rate-limit uint)
)
    (let (
        (platform-id (var-get next-platform-id))
    )
        (asserts! (is-owner tx-sender) err-owner-only)
        (asserts! (var-get system-active) err-unauthorized)
        (map-set registered-platforms
            { platform-id: platform-id }
            {
                name: name,
                api-endpoint: api-endpoint,
                supported-data-types: supported-data-types,
                authentication-method: authentication-method,
                rate-limit: rate-limit,
                active: true,
                total-users: u0,
                successful-exports: u0
            }
        )
        (var-set next-platform-id (+ platform-id u1))
        (ok platform-id)
    )
)

;; Connect user to a platform
(define-public (connect-platform
    (platform-id uint)
    (auth-token-hash (buff 32))
    (permissions (list 10 (string-ascii 50)))
    (data-types-enabled (list 20 (string-ascii 50)))
)
    (let (
        (user-id tx-sender)
        (platform-data (unwrap! (map-get? registered-platforms { platform-id: platform-id }) err-invalid-platform))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-platform-registered platform-id) err-invalid-platform)
        (asserts! (is-none (map-get? user-platform-connections { user-id: user-id, platform-id: platform-id })) err-already-exists)
        
        (map-set user-platform-connections
            { user-id: user-id, platform-id: platform-id }
            {
                connection-date: stacks-block-height,
                auth-token-hash: auth-token-hash,
                permissions: permissions,
                last-export: none,
                export-count: u0,
                status: "active",
                data-types-enabled: data-types-enabled
            }
        )
        
        ;; Update platform user count
        (map-set registered-platforms
            { platform-id: platform-id }
            (merge platform-data {
                total-users: (+ (get total-users platform-data) u1)
            })
        )
        
        (ok "Platform connected successfully")
    )
)

;; Schedule data export job
(define-public (schedule-export
    (platform-id uint)
    (data-types (list 20 (string-ascii 50)))
    (schedule-type (string-ascii 20))
    (frequency uint)
    (output-format (string-ascii 20))
    (storage-location (string-ascii 200))
)
    (let (
        (user-id tx-sender)
        (job-id (var-get next-job-id))
        (next-execution (calculate-next-execution frequency schedule-type))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (is-user-connected user-id platform-id) err-platform-not-connected)
        (asserts! (> frequency u0) err-invalid-schedule)
        
        (map-set export-jobs
            { job-id: job-id }
            {
                user-id: user-id,
                platform-id: platform-id,
                data-types: data-types,
                schedule-type: schedule-type,
                frequency: frequency,
                next-execution: next-execution,
                status: "scheduled",
                created-at: stacks-block-height,
                last-execution: none,
                output-format: output-format,
                storage-location: storage-location
            }
        )
        
        (var-set next-job-id (+ job-id u1))
        (ok job-id)
    )
)

;; Execute data export
(define-public (execute-export
    (job-id uint)
    (data-size uint)
    (files-exported (list 50 (string-ascii 100)))
)
    (let (
        (execution-id (var-get next-execution-id))
        (job-data (unwrap! (map-get? export-jobs { job-id: job-id }) err-not-found))
        (verification-hash (generate-verification-hash execution-id data-size))
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (or (is-eq tx-sender (get user-id job-data)) (is-owner tx-sender)) err-unauthorized)
        (asserts! (is-eq (get status job-data) "scheduled") err-invalid-schedule)
        
        ;; Record execution
        (map-set export-executions
            { execution-id: execution-id }
            {
                job-id: job-id,
                execution-date: stacks-block-height,
                status: "completed",
                data-size: data-size,
                verification-hash: verification-hash,
                error-message: none,
                completion-time: u0, ;; To be updated
                files-exported: files-exported
            }
        )
        
        ;; Update job with next execution time
        (map-set export-jobs
            { job-id: job-id }
            (merge job-data {
                last-execution: (some stacks-block-height),
                next-execution: (calculate-next-execution (get frequency job-data) (get schedule-type job-data))
            })
        )
        
        ;; Update user connection statistics
        (let (
            (connection-data (unwrap! (map-get? user-platform-connections 
                { user-id: (get user-id job-data), platform-id: (get platform-id job-data) }) err-not-found))
        )
            (map-set user-platform-connections
                { user-id: (get user-id job-data), platform-id: (get platform-id job-data) }
                (merge connection-data {
                    last-export: (some stacks-block-height),
                    export-count: (+ (get export-count connection-data) u1)
                })
            )
        )
        
        ;; Update platform analytics
        (update-platform-analytics (get platform-id job-data) true data-size)
        
        (var-set next-execution-id (+ execution-id u1))
        (ok execution-id)
    )
)

;; Verify exported data integrity
(define-public (verify-data-integrity
    (execution-id uint)
    (provided-hash (buff 32))
)
    (let (
        (verification-id (var-get next-verification-id))
        (execution-data (unwrap! (map-get? export-executions { execution-id: execution-id }) err-not-found))
        (original-hash (get verification-hash execution-data))
        (is-valid (is-eq original-hash provided-hash))
        (integrity-score (if is-valid u100 u0))
    )
        (asserts! (var-get system-active) err-unauthorized)
        
        (map-set data-verification
            { verification-id: verification-id }
            {
                execution-id: execution-id,
                original-hash: original-hash,
                verification-hash: provided-hash,
                verification-date: stacks-block-height,
                status: (if is-valid "verified" "failed"),
                verifier: tx-sender,
                integrity-score: integrity-score
            }
        )
        
        (var-set next-verification-id (+ verification-id u1))
        (ok {
            verification-id: verification-id,
            is-valid: is-valid,
            integrity-score: integrity-score
        })
    )
)

;; Set user preferences
(define-public (set-user-preferences
    (default-format (string-ascii 20))
    (encryption-enabled bool)
    (notification-settings (list 5 (string-ascii 30)))
    (storage-preference (string-ascii 50))
    (data-retention-period uint)
    (privacy-level uint)
)
    (let (
        (user-id tx-sender)
    )
        (asserts! (var-get system-active) err-unauthorized)
        (asserts! (<= privacy-level u10) err-unauthorized)
        
        (map-set user-preferences
            { user-id: user-id }
            {
                default-format: default-format,
                encryption-enabled: encryption-enabled,
                notification-settings: notification-settings,
                storage-preference: storage-preference,
                data-retention-period: data-retention-period,
                privacy-level: privacy-level
            }
        )
        
        (ok "User preferences updated successfully")
    )
)

;; Read-only Functions

;; Get platform information
(define-read-only (get-platform (platform-id uint))
    (map-get? registered-platforms { platform-id: platform-id })
)

;; Get user platform connection
(define-read-only (get-user-connection (user-id principal) (platform-id uint))
    (map-get? user-platform-connections { user-id: user-id, platform-id: platform-id })
)

;; Get export job information
(define-read-only (get-export-job (job-id uint))
    (map-get? export-jobs { job-id: job-id })
)

;; Get execution details
(define-read-only (get-execution-details (execution-id uint))
    (map-get? export-executions { execution-id: execution-id })
)

;; Get verification record
(define-read-only (get-verification-record (verification-id uint))
    (map-get? data-verification { verification-id: verification-id })
)

;; Get user preferences
(define-read-only (get-user-preferences (user-id principal))
    (map-get? user-preferences { user-id: user-id })
)

;; Get platform analytics
(define-read-only (get-platform-analytics (platform-id uint) (period uint))
    (map-get? platform-analytics { platform-id: platform-id, period: period })
)

;; Get system statistics
(define-read-only (get-system-stats)
    {
        next-platform-id: (var-get next-platform-id),
        next-job-id: (var-get next-job-id),
        next-execution-id: (var-get next-execution-id),
        total-users: (var-get total-users),
        system-active: (var-get system-active)
    }
)
